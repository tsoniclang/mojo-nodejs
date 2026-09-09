from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer
from ..http import ServerResponse
from .descriptor import StreamDescriptor
from .writable import Writable


@fieldwise_init
struct _ReadableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: List[Buffer]
    var paused: Bool
    var ended: Bool
    var path: String
    var chunk_size: Int
    var position: Optional[Int64]
    var end: Optional[Int64]
    var bytes_read: Int64
    var auto_close: Bool


struct Readable(ImplicitlyCopyable):
    var _state: ArcPointer[_ReadableState]

    def __init__(out self):
        self._state = ArcPointer(_ReadableState(None, List[Buffer](), False, False, "", 4096, None, None, 0, False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, chunk_size: Int,
                 start: Optional[Int64], end: Optional[Int64], auto_close: Bool):
        self._state = ArcPointer(_ReadableState(Optional(descriptor), List[Buffer](), False, False,
                                               path, chunk_size, start, end, 0, auto_close))

    def append(mut self, value: Buffer):
        self._state[].chunks.append(value)

    def read(mut self) raises -> Optional[Buffer]:
        if len(self._state[].chunks) != 0:
            var first = self._state[].chunks[0]
            var remaining = List[Buffer](capacity=len(self._state[].chunks) - 1)
            for index in range(1, len(self._state[].chunks)):
                remaining.append(self._state[].chunks[index])
            self._state[].chunks = remaining^
            return first
        if self._state[].ended or not self._state[].descriptor:
            return None
        var size = self._state[].chunk_size
        if self._state[].end:
            var position = self._state[].position.value() if self._state[].position else self._state[].bytes_read
            size = Int(min(Int64(size), max(0, self._state[].end.value() - position + 1)))
        var result = Optional[Buffer]()
        if size > 0:
            try:
                result = self._state[].descriptor.value().read(size, self._state[].position)
            except error:
                self._state[].ended = True
                if self._state[].auto_close:
                    self._state[].descriptor = None
                raise error^
        if not result:
            self._state[].ended = True
            if self._state[].auto_close:
                self.close()
            return None
        var count = Int64(len(result.value()))
        self._state[].bytes_read += count
        if self._state[].position:
            self._state[].position = self._state[].position.value() + count
        return result

    def close(self) raises:
        self._state[].ended = True
        if self._state[].descriptor:
            self._state[].descriptor.value().close()

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
