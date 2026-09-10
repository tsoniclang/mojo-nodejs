from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer
from ..buffer.codec import encode_bytes
from ..internal.callback_queue import Notification
from .completion import StreamCompletion
from .descriptor import StreamDescriptor
from .chunk import StreamChunk


@fieldwise_init
struct _WriteRequest(ImplicitlyCopyable):
    var chunk: Buffer
    var completion: Optional[StreamCompletion]


@fieldwise_init
struct _WritableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: List[_WriteRequest]
    var corked: Int
    var ended: Bool
    var closed: Bool
    var failed: Bool
    var buffered_bytes: Int64
    var high_water_mark: Int64
    var path: String
    var position: Optional[Int64]
    var bytes_written: Int64
    var auto_close: Bool
    var flush: Bool


struct Writable(ImplicitlyCopyable):
    var _state: ArcPointer[_WritableState]

    def __init__(out self):
        self._state = ArcPointer(_WritableState(None, List[_WriteRequest](), 0, False, False, False, 0, 65536, "", None, 0, False, False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, start: Optional[Int64], auto_close: Bool, flush: Bool, high_water_mark: Int64):
        self._state = ArcPointer(_WritableState(Optional(descriptor), List[_WriteRequest](), 0, False,
                                               False, False, 0, high_water_mark, path, start, 0, auto_close, flush))

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        return self._write(value, None)

    def _write(mut self, value: Buffer, callback: Optional[Notification]) raises -> Bool:
        if not self.writable():
            raise Error("Cannot write to an ended, closed or failed stream")
        if len(value) > 9007199254740991 - self._state[].buffered_bytes:
            raise Error("Stream buffered byte count exceeds the exact source range")
        var completion = Optional[StreamCompletion]()
        if callback:
            completion = StreamCompletion(callback.value())
        self._state[].chunks.append(_WriteRequest(value, completion))
        self._state[].buffered_bytes += len(value)
        if self._state[].corked == 0:
            self._flush()
        return self._state[].buffered_bytes < self._state[].high_water_mark or self._state[].buffered_bytes == 0

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def write_buffer_callback(mut self, value: Buffer, callback: Optional[Notification]) raises -> Bool:
        return self._write(value, callback)

    def write_string_callback(mut self, value: String, callback: Optional[Notification]) raises -> Bool:
        return self._write(Buffer.from_string(value), callback)

    def write_buffer_encoded(mut self, value: Buffer, _encoding: Optional[String] = None,
                            callback: Optional[Notification] = None) raises -> Bool:
        return self._write(value, callback)

    def write_string_encoded(mut self, value: String, encoding: Optional[String] = None,
                            callback: Optional[Notification] = None) raises -> Bool:
        return self._write(Buffer(encode_bytes(value, encoding.value() if encoding else "utf8")), callback)

    def write_value(mut self, value: StreamChunk) raises -> Bool:
        return self.write_value_encoded(value)

    def write_value_callback(mut self, value: StreamChunk, callback: Optional[Notification]) raises -> Bool:
        return self.write_value_encoded(value, None, callback)

    def write_value_encoded(mut self, value: StreamChunk, encoding: Optional[String] = None,
                           callback: Optional[Notification] = None) raises -> Bool:
        if value.isa[Buffer]():
            return self._write(value.unsafe_get[Buffer](), callback)
        return self.write_string_encoded(value.unsafe_get[String](), encoding, callback)

    def end(mut self) raises -> Self:
        return self._end(None)

    def _end(mut self, callback: Optional[Notification]) raises -> Self:
        var completion = Optional[StreamCompletion]()
        if callback:
            completion = StreamCompletion(callback.value())
        if self._state[].failed:
            raise Error("Cannot finish a failed stream")
        if self._state[].ended:
            if completion:
                completion.value().complete()
            return self
        self._state[].ended = True
        self._state[].corked = 0
        try:
            self._flush()
            if len(self._state[].chunks) != 0:
                raise Error("Cannot complete a stream without a writable sink")
            if self._state[].flush and self._state[].descriptor:
                self._state[].descriptor.value().flush()
        except error:
            self._state[].failed = True
            raise error^
        finally:
            if self._state[].auto_close:
                self._close_descriptor()
        if completion:
            completion.value().complete()
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def end_callback(mut self, callback: Optional[Notification]) raises -> Self:
        return self._end(callback)

    def end_buffer_callback(mut self, value: Buffer, callback: Optional[Notification]) raises -> Self:
        return self.end_buffer_encoded(value, None, callback)

    def end_string_callback(mut self, value: String, callback: Optional[Notification]) raises -> Self:
        return self.end_string_encoded(value, None, callback)

    def end_buffer_encoded(mut self, value: Buffer, _encoding: Optional[String] = None,
                          callback: Optional[Notification] = None) raises -> Self:
        return self._end_chunk(value, callback)

    def end_string_encoded(mut self, value: String, encoding: Optional[String] = None,
                          callback: Optional[Notification] = None) raises -> Self:
        return self._end_chunk(Buffer(encode_bytes(value, encoding.value() if encoding else "utf8")), callback)

    def end_empty_encoded(mut self, _chunk: NoneType, _encoding: Optional[String] = None,
                         callback: Optional[Notification] = None) raises -> Self:
        return self._end(callback)

    def end_empty(mut self, _chunk: NoneType) raises -> Self:
        return self.end()

    def end_empty_callback(mut self, _chunk: NoneType, callback: Optional[Notification]) raises -> Self:
        return self._end(callback)

    def end_value(mut self, value: Optional[StreamChunk]) raises -> Self:
        return self.end_value_encoded(value)

    def end_value_callback(mut self, value: Optional[StreamChunk], callback: Optional[Notification]) raises -> Self:
        return self.end_value_encoded(value, None, callback)

    def end_value_encoded(mut self, value: Optional[StreamChunk], encoding: Optional[String] = None,
                         callback: Optional[Notification] = None) raises -> Self:
        if not value:
            return self._end(callback)
        var chunk = value.value()
        if chunk.isa[Buffer]():
            return self._end_chunk(chunk.unsafe_get[Buffer](), callback)
        return self.end_string_encoded(chunk.unsafe_get[String](), encoding, callback)

    def _end_chunk(mut self, value: Buffer, callback: Optional[Notification]) raises -> Self:
        var completion = Optional[StreamCompletion]()
        if callback:
            completion = StreamCompletion(callback.value())
        _ = self.write_buffer(value)
        _ = self.end()
        if completion:
            completion.value().complete()
        return self

    def close(mut self) raises:
        try:
            _ = self.end()
        finally:
            self._close_descriptor()

    def _close_descriptor(self) raises:
        self._state[].closed = True
        if self._state[].descriptor:
            try:
                self._state[].descriptor.value().close()
            except error:
                self._state[].failed = True
                raise error^

    def writable(self) -> Bool:
        return not self._state[].ended and not self._state[].closed and not self._state[].failed

    def writable_ended(self) -> Bool:
        return self._state[].ended

    def path(self) -> String:
        return self._state[].path

    def bytes_written(self) -> Float64:
        if self._state[].descriptor:
            return Float64(self._state[].descriptor.value().bytes_written())
        return Float64(self._state[].bytes_written)

    def cork(mut self):
        self._state[].corked += 1

    def uncork(mut self) raises:
        if self._state[].corked > 0:
            self._state[].corked -= 1
            if self._state[].corked == 0:
                self._flush()

    def writable_corked(self) -> Float64:
        return Float64(self._state[].corked)

    def _flush(mut self) raises:
        if not self._state[].descriptor:
            return
        var chunks = List[_WriteRequest]()
        swap(chunks, self._state[].chunks)
        try:
            for request in chunks:
                var count = self._state[].descriptor.value().write(request.chunk, self._state[].position)
                self._state[].bytes_written += count
                self._state[].buffered_bytes -= count
                if self._state[].position:
                    self._state[].position = self._state[].position.value() + count
                if request.completion:
                    request.completion.value().complete()
        except error:
            self._state[].failed = True
            if self._state[].auto_close:
                self._state[].bytes_written = self._state[].descriptor.value().bytes_written()
                self._state[].descriptor = None
            raise error^
        finally:
            self._state[].buffered_bytes = 0
