from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer
from .descriptor import StreamDescriptor


@fieldwise_init
struct _WritableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: List[Buffer]
    var corked: Bool
    var ended: Bool
    var path: String
    var position: Optional[Int64]
    var bytes_written: Int64
    var auto_close: Bool
    var flush: Bool


struct Writable(ImplicitlyCopyable):
    var _state: ArcPointer[_WritableState]

    def __init__(out self):
        self._state = ArcPointer(_WritableState(None, List[Buffer](), False, False, "", None, 0, False, False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, start: Optional[Int64], auto_close: Bool, flush: Bool):
        self._state = ArcPointer(_WritableState(Optional(descriptor), List[Buffer](), False, False,
                                               path, start, 0, auto_close, flush))

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        if self._state[].ended:
            raise Error("Cannot write after stream end")
        self._state[].chunks.append(value)
        if not self._state[].corked:
            self._flush()
        return True

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def end(mut self) raises -> Self:
        self._state[].corked = False
        try:
            self._flush()
            if self._state[].flush and self._state[].descriptor:
                self._state[].descriptor.value().flush()
        finally:
            self._state[].ended = True
            if self._state[].auto_close:
                self.close()
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def close(self) raises:
        self._state[].ended = True
        if self._state[].descriptor:
            self._state[].descriptor.value().close()

    def path(self) -> String:
        return self._state[].path

    def bytes_written(self) -> Float64:
        if self._state[].descriptor:
            return Float64(self._state[].descriptor.value().bytes_written())
        return Float64(self._state[].bytes_written)

    def cork(mut self):
        self._state[].corked = True

    def uncork(mut self) raises:
        self._state[].corked = False
        self._flush()

    def _flush(mut self) raises:
        if not self._state[].descriptor:
            return
        var chunks = List[Buffer]()
        swap(chunks, self._state[].chunks)
        try:
            for chunk in chunks:
                var count = self._state[].descriptor.value().write(chunk, self._state[].position)
                self._state[].bytes_written += count
                if self._state[].position:
                    self._state[].position = self._state[].position.value() + count
        except error:
            self._state[].ended = True
            if self._state[].auto_close:
                self._state[].bytes_written = self._state[].descriptor.value().bytes_written()
                self._state[].descriptor = None
            raise error^
