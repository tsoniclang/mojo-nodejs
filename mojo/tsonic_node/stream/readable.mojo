from std.memory import ArcPointer
from ..buffer import Buffer
from ..http import ServerResponse
from .descriptor import StreamDescriptor
from .byte_queue import ByteQueue
from .read_size import requested_read_size, increased_read_threshold
from .writable import Writable


@fieldwise_init
struct _ReadableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: ByteQueue
    var paused: Bool
    var ended: Bool
    var closed: Bool
    var failed: Bool
    var eof: Bool
    var path: String
    var chunk_size: Int
    var position: Optional[Int64]
    var end: Optional[Int64]
    var bytes_read: Int64
    var auto_close: Bool


struct Readable(ImplicitlyCopyable):
    var _state: ArcPointer[_ReadableState]

    def __init__(out self):
        self._state = ArcPointer(_ReadableState(None, ByteQueue(), False, False, False, False, False, "", 4096, None, None, 0, False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, chunk_size: Int,
                 start: Optional[Int64], end: Optional[Int64], auto_close: Bool):
        self._state = ArcPointer(_ReadableState(Optional(descriptor), ByteQueue(), False, False, False, False, False,
                                               path, chunk_size, start, end, 0, auto_close))

    def append(mut self, value: Buffer) raises:
        if self._state[].closed or self._state[].failed or self._state[].eof:
            raise Error("Cannot append to a closed or ended readable stream")
        self._state[].chunks.append(value)

    def read(mut self) raises -> Optional[Buffer]:
        return self.read_sized(None)

    def read_sized(mut self, requested: Optional[Float64]) raises -> Optional[Buffer]:
        var selected = requested_read_size(requested)
        if selected:
            self._state[].chunk_size = increased_read_threshold(selected.value(), self._state[].chunk_size)
        if self._state[].closed or self._state[].failed:
            return None
        var desired = self._state[].chunk_size
        if selected:
            desired = Int(selected.value()) if selected.value() > 0 else 0
        if self._state[].chunks.length < desired or self._state[].chunks.length == 0:
            self._fill()
        if self._state[].chunks.length == 0 and self._state[].eof:
            self._state[].ended = True
            if self._state[].auto_close:
                self.close()
            return None
        if selected:
            if selected.value() <= 0:
                return None
            if self._state[].chunks.length < desired and not self._state[].eof:
                return None
            return self._state[].chunks.take(min(desired, self._state[].chunks.length))
        return self._state[].chunks.take(self._state[].chunks.length)

    def _fill(mut self) raises:
        if self._state[].eof or not self._state[].descriptor:
            return
        var size = self._state[].chunk_size
        if self._state[].end:
            var position = self._state[].position.value() if self._state[].position else self._state[].bytes_read
            size = Int(min(Int64(size), max(0, self._state[].end.value() - position + 1)))
            if position > self._state[].end.value():
                self._state[].eof = True
        if size == 0:
            return
        try:
            var result = self._state[].descriptor.value().read(size, self._state[].position)
            if not result:
                self._state[].eof = True
                return
            var count = Int64(len(result.value()))
            self._state[].bytes_read += count
            if self._state[].position:
                self._state[].position = self._state[].position.value() + count
            self._state[].chunks.append(result.value())
        except error:
            self._state[].failed = True
            self._state[].chunks.clear()
            if self._state[].auto_close:
                self._state[].descriptor = None
            raise error^

    def close(self) raises:
        self._state[].closed = True
        self._state[].chunks.clear()
        if self._state[].descriptor:
            self._state[].descriptor.value().close()

    def readable(self) -> Bool:
        return not self._state[].ended and not self._state[].closed and not self._state[].failed

    def readable_ended(self) -> Bool:
        return self._state[].ended

    def path(self) -> String:
        return self._state[].path

    def bytes_read(self) -> Float64:
        return Float64(self._state[].bytes_read)

    def pipe_to(mut self, mut destination: Writable) raises -> Writable:
        while True:
            var value = self.read()
            if not value:
                break
            _ = destination.write_buffer(value.value())
        _ = destination.end()
        return destination

    def pipe_to_response(mut self, destination: ServerResponse) raises -> ServerResponse:
        var output = destination
        while True:
            var value = self.read()
            if not value:
                break
            _ = output.write_buffer(value.value())
        output.end_empty()
        return output

    def pause(mut self) -> Self:
        self._state[].paused = True
        return self

    def resume(mut self) -> Self:
        self._state[].paused = False
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused
