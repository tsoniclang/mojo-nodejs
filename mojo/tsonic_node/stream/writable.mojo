from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import RaisingCallable, TsError, error_new
from ..buffer import Buffer
from ..buffer.codec import encode_bytes
from ..internal.callback_queue import Notification
from .completion import StreamCompletion, WriteCallback
from .descriptor import StreamDescriptor
from .chunk import StreamChunk
from .write_events import WriteEvents


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
    var end_on_pipe: Bool
    var events: WriteEvents
    var need_drain: Bool


struct Writable(ImplicitlyCopyable):
    var _state: ArcPointer[_WritableState]

    def __init__(out self):
        self._state = ArcPointer(_WritableState(None, List[_WriteRequest](), 0, False, False, False, 0, 65536, "", None, 0, False, False, True,
                                               WriteEvents(), False))

    def __init__(out self, descriptor: Int32, end_on_pipe: Bool = True):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)
        self._state[].end_on_pipe = end_on_pipe

    def __init__(out self, descriptor: StreamDescriptor, path: String, start: Optional[Int64], auto_close: Bool, flush: Bool, high_water_mark: Int64):
        self._state = ArcPointer(_WritableState(Optional(descriptor), List[_WriteRequest](), 0, False,
                                               False, False, 0, high_water_mark, path, start, 0, auto_close, flush, True,
                                               WriteEvents(), False))

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        return self._write(value, None)

    def _write(mut self, value: Buffer, callback: Optional[WriteCallback]) raises -> Bool:
        self._state[].events.prepare()
        if len(value) > 9007199254740991 - self._state[].buffered_bytes:
            raise Error("Stream buffered byte count exceeds the exact source range")
        var completion = Optional[StreamCompletion]()
        if callback:
            completion = StreamCompletion(callback.value())
        if not self.writable():
            var error = self._failure("Cannot write to an ended, closed or failed stream")
            if completion:
                completion.value().complete(error.copy())
            self._fail(error)
            return False
        self._state[].chunks.append(_WriteRequest(value, completion))
        self._state[].buffered_bytes += len(value)
        if self._state[].corked == 0:
            self._flush()
        var ready = self._state[].buffered_bytes < self._state[].high_water_mark or self._state[].buffered_bytes == 0
        self._state[].need_drain = self._state[].need_drain or not ready
        return ready and not self._state[].failed

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def write_buffer_callback(mut self, value: Buffer, callback: Optional[WriteCallback]) raises -> Bool:
        return self._write(value, callback)

    def write_string_callback(mut self, value: String, callback: Optional[WriteCallback]) raises -> Bool:
        return self._write(Buffer.from_string(value), callback)

    def write_buffer_encoded(mut self, value: Buffer, _encoding: Optional[String] = None,
                            callback: Optional[WriteCallback] = None) raises -> Bool:
        return self._write(value, callback)

    def write_string_encoded(mut self, value: String, encoding: Optional[String] = None,
                            callback: Optional[WriteCallback] = None) raises -> Bool:
        return self._write(Buffer(encode_bytes(value, encoding.value() if encoding else "utf8")), callback)

    def write_value(mut self, value: StreamChunk) raises -> Bool:
        return self.write_value_encoded(value)

    def write_value_callback(mut self, value: StreamChunk, callback: Optional[WriteCallback]) raises -> Bool:
        return self.write_value_encoded(value, None, callback)

    def write_value_encoded(mut self, value: StreamChunk, encoding: Optional[String] = None,
                           callback: Optional[WriteCallback] = None) raises -> Bool:
        if value.isa[Buffer]():
            return self._write(value.unsafe_get[Buffer](), callback)
        return self.write_string_encoded(value.unsafe_get[String](), encoding, callback)

    def end(mut self) raises -> Self:
        return self._end(None)

    def _end(mut self, callback: Optional[WriteCallback]) raises -> Self:
        self._retain_end(callback)
        return self._finish()

    def _retain_end(self, callback: Optional[WriteCallback]) raises:
        self._state[].events.prepare()
        if callback:
            self._state[].events.retain_end(callback.value())

    def _finish(mut self) raises -> Self:
        if self._state[].failed:
            return self
        if self._state[].ended:
            return self
        self._state[].ended = True
        self._state[].corked = 0
        self._flush()
        if self._state[].failed:
            return self
        try:
            if len(self._state[].chunks) != 0:
                raise Error("Cannot complete a stream without a writable sink")
            if self._state[].flush and self._state[].descriptor:
                self._state[].descriptor.value().flush()
            if self._state[].auto_close:
                self._close_descriptor()
        except error:
            self._fail(error_new(String(error)))
            return self
        self._state[].events.finish()
        if self._state[].closed:
            self._state[].events.close()
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def end_callback(mut self, callback: Optional[WriteCallback]) raises -> Self:
        return self._end(callback)

    def end_buffer_callback(mut self, value: Buffer, callback: Optional[WriteCallback]) raises -> Self:
        return self.end_buffer_encoded(value, None, callback)

    def end_string_callback(mut self, value: String, callback: Optional[WriteCallback]) raises -> Self:
        return self.end_string_encoded(value, None, callback)

    def end_buffer_encoded(mut self, value: Buffer, _encoding: Optional[String] = None,
                          callback: Optional[WriteCallback] = None) raises -> Self:
        return self._end_chunk(value, callback)

    def end_string_encoded(mut self, value: String, encoding: Optional[String] = None,
                          callback: Optional[WriteCallback] = None) raises -> Self:
        return self._end_chunk(Buffer(encode_bytes(value, encoding.value() if encoding else "utf8")), callback)

    def end_empty_encoded(mut self, _chunk: NoneType, _encoding: Optional[String] = None,
                         callback: Optional[WriteCallback] = None) raises -> Self:
        return self._end(callback)

    def end_empty(mut self, _chunk: NoneType) raises -> Self:
        return self.end()

    def end_empty_callback(mut self, _chunk: NoneType, callback: Optional[WriteCallback]) raises -> Self:
        return self._end(callback)

    def end_value(mut self, value: Optional[StreamChunk]) raises -> Self:
        return self.end_value_encoded(value)

    def end_value_callback(mut self, value: Optional[StreamChunk], callback: Optional[WriteCallback]) raises -> Self:
        return self.end_value_encoded(value, None, callback)

    def end_value_encoded(mut self, value: Optional[StreamChunk], encoding: Optional[String] = None,
                         callback: Optional[WriteCallback] = None) raises -> Self:
        if not value:
            return self._end(callback)
        var chunk = value.value()
        if chunk.isa[Buffer]():
            return self._end_chunk(chunk.unsafe_get[Buffer](), callback)
        return self.end_string_encoded(chunk.unsafe_get[String](), encoding, callback)

    def _end_chunk(mut self, value: Buffer, callback: Optional[WriteCallback]) raises -> Self:
        self._retain_end(callback)
        _ = self.write_buffer(value)
        return self._finish()

    def close(mut self) raises:
        self._state[].events.prepare()
        try:
            _ = self.end()
        finally:
            if not self._state[].closed:
                self._close_descriptor()
            self._state[].events.close()

    def _close_descriptor(self) raises:
        self._state[].closed = True
        if self._state[].descriptor:
            self._state[].descriptor.value().close()

    def writable(self) -> Bool:
        return not self._state[].ended and not self._state[].closed and not self._state[].failed

    def writable_ended(self) -> Bool:
        return self._state[].ended

    def pipe_needs_drain(self) -> Bool:
        return self._state[].buffered_bytes != 0 or self._state[].events.state[].drain_scheduled

    def end_from_pipe(mut self) raises:
        if self._state[].end_on_pipe:
            _ = self.end()

    def path(self) -> String:
        return self._state[].path

    def bytes_written(self) -> Float64:
        if self._state[].descriptor:
            return Float64(self._state[].descriptor.value().bytes_written())
        return Float64(self._state[].bytes_written)

    def cork(mut self):
        self._state[].corked += 1

    def uncork(mut self) raises:
        self._state[].events.prepare()
        if self._state[].corked > 0:
            self._state[].corked -= 1
            if self._state[].corked == 0:
                self._flush()

    def writable_corked(self) -> Float64:
        return Float64(self._state[].corked)

    def _flush(mut self) raises:
        if not self._state[].descriptor or self._state[].failed:
            return
        var completed = 0
        while completed < len(self._state[].chunks):
            var request = self._state[].chunks[completed]
            try:
                var count = self._state[].descriptor.value().write(request.chunk, self._state[].position)
                self._state[].bytes_written += count
                self._state[].buffered_bytes -= count
                if self._state[].position:
                    self._state[].position = self._state[].position.value() + count
            except error:
                self._fail(error_new(String(error)), completed)
                return
            if request.completion:
                request.completion.value().complete()
            completed += 1
        self._state[].chunks.clear()
        if self._state[].need_drain:
            self._state[].need_drain = False
            self._state[].events.drain()

    def _failure(self, message: String) -> TsError:
        if self._state[].events.state[].error:
            return self._state[].events.state[].error.value().copy()
        return error_new(message)

    def _fail(self, error: TsError, completed: Int = 0) raises:
        self._state[].failed = True
        for index in range(completed, len(self._state[].chunks)):
            var completion = self._state[].chunks[index].completion
            if completion:
                completion.value().complete(error.copy())
        self._state[].chunks.clear()
        self._state[].buffered_bytes = 0
        self._state[].events.complete_end(error.copy())
        self._state[].events.fail(error)
        if self._state[].auto_close:
            self._state[].closed = True
            if self._state[].descriptor:
                self._state[].bytes_written = self._state[].descriptor.value().bytes_written()
                self._state[].descriptor = None
            self._state[].events.close()

    def on_empty(mut self, event: String, callback: Notification) raises -> Self:
        self._state[].events.notifications(event).add(callback)
        return self

    def once_empty(mut self, event: String, callback: Notification) raises -> Self:
        self._state[].events.notifications(event).add(callback, True)
        return self

    def off_empty(mut self, event: String, callback: Notification) raises -> Self:
        self._state[].events.notifications(event).remove(callback)
        return self

    def on_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        if event != "error":
            raise Error("Expected the writable error event")
        self._state[].events.state[].errors.add(callback)
        return self

    def once_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        if event != "error":
            raise Error("Expected the writable error event")
        self._state[].events.state[].errors.add(callback, True)
        return self

    def off_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        if event != "error":
            raise Error("Expected the writable error event")
        self._state[].events.state[].errors.remove(callback)
        return self
