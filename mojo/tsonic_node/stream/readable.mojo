from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell
from ..buffer import Buffer
from ..buffer.codec import encoding_name
from ..http import ServerResponse
from .descriptor import StreamDescriptor
from .read_buffer import ReadBuffer
from .chunk import StreamChunk
from .native_read import NativeRead
from .read_size import requested_read_size, increased_read_threshold
from .writable import Writable
from .pipe_sink import PipeSink


@fieldwise_init
struct _ReadableState:
    var descriptor: Optional[StreamDescriptor]
    var chunks: ReadBuffer
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
    var asynchronous: Bool
    var native_read: Optional[NativeRead]
    var pipes: List[PipeSink]
    var pipe_registered: Bool


struct Readable(ImplicitlyCopyable):
    var _state: ArcPointer[_ReadableState]

    def __init__(out self):
        self._state = ArcPointer(_ReadableState(None, ReadBuffer(), False, False, False, False, False, "", 4096, None, None, 0, False, False, None, List[PipeSink](), False))

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, descriptor: StreamDescriptor, path: String, chunk_size: Int,
                 start: Optional[Int64], end: Optional[Int64], auto_close: Bool):
        self._state = ArcPointer(_ReadableState(Optional(descriptor), ReadBuffer(), False, False, False, False, False,
                                               path, chunk_size, start, end, 0, auto_close, False, None, List[PipeSink](), False))

    def append(mut self, value: Buffer) raises:
        if self._state[].closed or self._state[].failed or self._state[].eof:
            raise Error("Cannot append to a closed or ended readable stream")
        try:
            self._state[].chunks.append(value)
        except error:
            self._abort()
            raise error^

    def read(mut self) raises -> Optional[StreamChunk]:
        return self.read_sized(None)

    def read_sized(mut self, requested: Optional[Float64]) raises -> Optional[StreamChunk]:
        var selected = requested_read_size(requested)
        if selected:
            self._state[].chunk_size = increased_read_threshold(selected.value(), self._state[].chunk_size)
        if self._state[].closed or self._state[].failed:
            return None
        var desired = self._state[].chunk_size
        if selected:
            desired = Int(selected.value()) if selected.value() > 0 else 0
        if len(self._state[].chunks) < desired or len(self._state[].chunks) == 0:
            var minimum = desired if selected else 1
            self._fill(1 if minimum > 0 else 0)
            while self._state[].descriptor and not self._state[].eof and len(self._state[].chunks) < minimum:
                var previous_bytes = self._state[].bytes_read
                self._fill(1)
                if previous_bytes == self._state[].bytes_read:
                    break
        if len(self._state[].chunks) == 0 and self._state[].eof:
            self._state[].ended = True
            if self._state[].auto_close:
                self.close()
            return None
        if selected:
            if selected.value() <= 0:
                return None
            if len(self._state[].chunks) < desired and not self._state[].eof:
                return None
            return self._state[].chunks.take(min(desired, len(self._state[].chunks)))
        return self._state[].chunks.take(len(self._state[].chunks))

    def set_encoding(mut self, name: String) raises -> Self:
        var selected = encoding_name(name)
        try:
            self._state[].chunks.set_encoding(selected)
        except error:
            self._abort()
            raise error^
        return self

    def _fill(mut self, minimum: Int = 0) raises:
        try:
            if self._state[].asynchronous:
                self._poll_descriptor(minimum)
            else:
                self._read_descriptor(minimum)
        except error:
            self._abort()
            raise error^

    def _abort(self):
        self._state[].failed = True
        self._state[].native_read = None
        self._state[].chunks.clear()
        if self._state[].auto_close:
            self._state[].descriptor = None

    def poll_input(mut self) raises -> Bool:
        self._state[].asynchronous = True
        if self._state[].closed or self._state[].failed:
            return False
        var before = self._state[].bytes_read
        var eof = self._state[].eof
        var pending = Bool(self._state[].native_read)
        if len(self._state[].chunks) == 0 or pending:
            self._fill(1)
        return before != self._state[].bytes_read or eof != self._state[].eof or pending != Bool(self._state[].native_read)

    def input_ended(self) -> Bool:
        return self._state[].eof or self._state[].closed or self._state[].failed

    def _poll_descriptor(mut self, minimum: Int) raises:
        if self._state[].native_read:
            if not self._state[].native_read.value().ready():
                return
            var result = self._state[].native_read.value().result()
            self._state[].native_read = None
            self._accept_read(result)
            return
        var size = min(1048576, self._request_size(minimum))
        if size > 0:
            self._state[].native_read = self._state[].descriptor.value().begin_read(size, self._state[].position)

    def _request_size(mut self, minimum: Int) raises -> Int:
        if self._state[].eof or not self._state[].descriptor:
            return 0
        var size = max(minimum, self._state[].chunk_size)
        if self._state[].end:
            var position = self._state[].position.value() if self._state[].position else self._state[].bytes_read
            size = Int(min(Int64(size), max(0, self._state[].end.value() - position + 1)))
            if position > self._state[].end.value():
                self._state[].eof = True
                self._state[].chunks.finish()
        return size

    def _read_descriptor(mut self, minimum: Int) raises:
        var size = self._request_size(minimum)
        if size == 0:
            return
        var result = self._state[].descriptor.value().read(size, self._state[].position)
        self._accept_read(result)

    def _accept_read(mut self, result: Optional[Buffer]) raises:
        if not result:
            self._state[].eof = True
            self._state[].chunks.finish()
            return
        var count = Int64(len(result.value()))
        self._state[].bytes_read += count
        if self._state[].position:
            self._state[].position = self._state[].position.value() + count
        self._state[].chunks.append(result.value())

    def close(self) raises:
        self._state[].closed = True
        self._state[].native_read = None
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
        self._add_pipe(PipeSink(destination))
        return destination

    def pipe_to_response(mut self, destination: ServerResponse) raises -> ServerResponse:
        self._add_pipe(PipeSink(destination))
        return destination

    def _add_pipe(mut self, sink: PipeSink) raises:
        if len(self._state[].pipes) >= 1024:
            raise Error("Readable pipe destinations exceed the finite runtime limit")
        if not self._state[].pipe_registered:
            _prune_pipes()
            if len(_pipe_sources.get()[]) >= 16384:
                raise Error("Active stream pipes exceed the finite runtime limit")
            _pipe_sources.get()[].append(self)
            self._state[].pipe_registered = True
        self._state[].pipes.append(sink)
        self._state[].asynchronous = True
        self._state[].paused = False

    def _poll_pipe(mut self) raises -> Bool:
        if self._state[].failed or self._state[].closed and not self._state[].ended:
            self._state[].pipes.clear()
            return False
        var retained = List[PipeSink]()
        var blocked = False
        var previous = len(self._state[].pipes)
        for index in range(previous):
            var sink = self._state[].pipes[index]
            if sink.writable():
                blocked = not sink.ready() or blocked
                retained.append(sink)
        self._state[].pipes = retained^
        var changed = previous != len(self._state[].pipes)
        if len(self._state[].pipes) == 0 or self._state[].paused or blocked:
            return changed
        try:
            var worked = self.poll_input() or changed
            var value = self.read()
            if value:
                for index in range(len(self._state[].pipes)):
                    self._state[].pipes[index].write(value.value())
                return True
            if self._state[].ended:
                var sinks = List[PipeSink]()
                swap(sinks, self._state[].pipes)
                for index in range(len(sinks)):
                    sinks[index].end()
                return True
            return worked
        except error:
            self._state[].pipes.clear()
            raise error^

    def pause(mut self) -> Self:
        self._state[].paused = True
        return self

    def resume(mut self) -> Self:
        self._state[].paused = False
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused


def _initial_pipe_sources() -> List[Readable]:
    return List[Readable]()


comptime _pipe_sources = GlobalCell["tsonic.node.stream.pipes", _initial_pipe_sources]()


def _prune_pipes():
    var retained = List[Readable]()
    for source in _pipe_sources.get()[]:
        if len(source._state[].pipes) != 0:
            retained.append(source)
        else:
            source._state[].pipe_registered = False
    _pipe_sources.get()[] = retained^


def has_active_pipes() -> Bool:
    _prune_pipes()
    return len(_pipe_sources.get()[]) != 0


def poll_pipes() raises -> Bool:
    var worked = False
    var snapshot = _pipe_sources.get()[].copy()
    try:
        for index in range(len(snapshot)):
            var source = snapshot[index]
            worked = source._poll_pipe() or worked
    finally:
        _prune_pipes()
    return worked
