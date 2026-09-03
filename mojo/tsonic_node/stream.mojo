from std.collections import List
from std.ffi import c_int, c_size_t, c_ssize_t, external_call
from std.memory import ArcPointer

from .buffer import Buffer
from .http import ServerResponse


@fieldwise_init
struct _ReadableState:
    var descriptor: Optional[Int32]
    var chunks: List[Buffer]
    var paused: Bool
    var ended: Bool


struct Readable(ImplicitlyCopyable):
    var _state: ArcPointer[_ReadableState]

    def __init__(out self):
        self._state = ArcPointer(
            _ReadableState(None, List[Buffer](), False, False)
        )

    def __init__(out self, descriptor: Int32):
        self._state = ArcPointer(
            _ReadableState(
                Optional[Int32](descriptor), List[Buffer](), False, False
            )
        )

    def append(mut self, value: Buffer):
        self._state[].chunks.append(value)

    def read(mut self) raises -> Optional[Buffer]:
        if len(self._state[].chunks) != 0:
            var first = self._state[].chunks[0]
            var remaining = List[Buffer](capacity=len(self._state[].chunks) - 1)
            for index in range(1, len(self._state[].chunks)):
                remaining.append(self._state[].chunks[index])
            self._state[].chunks = remaining^
            return Optional[Buffer](first)
        if self._state[].ended or not self._state[].descriptor:
            return None
        var bytes = List[Byte](capacity=4096)
        for _ in range(4096):
            bytes.append(0)
        var count = external_call["read", c_ssize_t](
            c_int(self._state[].descriptor.value()),
            bytes.unsafe_ptr(),
            c_size_t(4096),
        )
        if count < 0:
            raise Error("Unable to read from stream")
        if count == 0:
            self._state[].ended = True
            return None
        var result = List[Byte](capacity=count)
        for index in range(count):
            result.append(bytes[index])
        return Optional[Buffer](Buffer(result^))

    def pipe_to(mut self, mut destination: Writable) raises -> Writable:
        while True:
            var value = self.read()
            if not value:
                break
            _ = destination.write_buffer(value.value())
        return destination

    def pipe_to_response(
        mut self, destination: ServerResponse
    ) raises -> ServerResponse:
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


@fieldwise_init
struct _WritableState:
    var descriptor: Optional[Int32]
    var chunks: List[Buffer]
    var corked: Bool
    var ended: Bool


struct Writable(ImplicitlyCopyable):
    var _state: ArcPointer[_WritableState]

    def __init__(out self):
        self._state = ArcPointer(
            _WritableState(None, List[Buffer](), False, False)
        )

    def __init__(out self, descriptor: Int32):
        self._state = ArcPointer(
            _WritableState(
                Optional[Int32](descriptor), List[Buffer](), False, False
            )
        )

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
        self._flush()
        self._state[].ended = True
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def cork(mut self):
        self._state[].corked = True

    def uncork(mut self) raises:
        self._state[].corked = False
        self._flush()

    def _flush(mut self) raises:
        if not self._state[].descriptor:
            return
        var descriptor = self._state[].descriptor.value()
        for chunk in self._state[].chunks:
            var bytes = chunk.copy_bytes()
            var offset = 0
            while offset < len(bytes):
                var written = external_call["write", c_ssize_t](
                    Int(descriptor).__mlir_index__(),
                    bytes.unsafe_ptr().unsafe_offset(offset),
                    (len(bytes) - offset).__mlir_index__(),
                )
                if written <= 0:
                    raise Error("Unable to write stream")
                offset += written
        self._state[].chunks = List[Buffer]()


def stdin() -> Readable:
    return Readable(0)


def stdout() -> Writable:
    return Writable(1)


def stderr() -> Writable:
    return Writable(2)
