from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer
from .descriptor import StreamDescriptor


@fieldwise_init
struct _WritableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: List[Buffer]
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
        self._state = ArcPointer(_WritableState(None, List[Buffer](), 0, False, False, False, 0, 65536, "", None, 0, False, False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, start: Optional[Int64], auto_close: Bool, flush: Bool, high_water_mark: Int64):
        self._state = ArcPointer(_WritableState(Optional(descriptor), List[Buffer](), 0, False,
                                               False, False, 0, high_water_mark, path, start, 0, auto_close, flush))

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        if not self.writable():
            raise Error("Cannot write to an ended, closed or failed stream")
        if len(value) > 9007199254740991 - self._state[].buffered_bytes:
            raise Error("Stream buffered byte count exceeds the exact source range")
        self._state[].chunks.append(value)
        self._state[].buffered_bytes += len(value)
        if self._state[].corked == 0:
            self._flush()
        return self._state[].buffered_bytes < self._state[].high_water_mark or self._state[].buffered_bytes == 0

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def end(mut self) raises -> Self:
        if self._state[].ended:
            return self
        self._state[].ended = True
        self._state[].corked = 0
        try:
            self._flush()
            if self._state[].flush and self._state[].descriptor:
                self._state[].descriptor.value().flush()
        finally:
            if self._state[].auto_close:
                self._close_descriptor()
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def close(mut self) raises:
        try:
            _ = self.end()
        finally:
            self._close_descriptor()

    def _close_descriptor(self) raises:
        self._state[].closed = True
        if self._state[].descriptor:
            self._state[].descriptor.value().close()

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
        var chunks = List[Buffer]()
        swap(chunks, self._state[].chunks)
        try:
            for chunk in chunks:
                var count = self._state[].descriptor.value().write(chunk, self._state[].position)
                self._state[].bytes_written += count
                self._state[].buffered_bytes -= count
                if self._state[].position:
                    self._state[].position = self._state[].position.value() + count
        except error:
            self._state[].failed = True
            if self._state[].auto_close:
                self._state[].bytes_written = self._state[].descriptor.value().bytes_written()
                self._state[].descriptor = None
            raise error^
        finally:
            self._state[].buffered_bytes = 0
