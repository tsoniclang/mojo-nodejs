from std.collections import List
from std.ffi import c_int, c_size_t, external_call, get_errno
from std.memory import ArcPointer
from ..buffer import Buffer
from .native_read import NativeRead


struct _DescriptorState(Movable):
    var descriptor: Int32
    var owned: Bool
    var bytes_written: Int64

    def __init__(out self, descriptor: Int32, owned: Bool):
        self.descriptor = descriptor
        self.owned = owned
        self.bytes_written = 0

    def __deinit__(deinit self):
        if self.owned and self.descriptor >= 0:
            _ = external_call["close", c_int](c_int(self.descriptor))


struct StreamDescriptor(ImplicitlyCopyable):
    var _state: ArcPointer[_DescriptorState]

    def __init__(out self, descriptor: Int32, owned: Bool = False):
        self._state = ArcPointer(_DescriptorState(descriptor, owned))

    def is_open(self) -> Bool:
        return self._state[].descriptor >= 0

    def bytes_written(self) -> Int64:
        return self._state[].bytes_written

    def begin_read(
        self, size: Int, offset: Optional[Int64]
    ) raises -> NativeRead:
        if not self.is_open():
            raise Error("Cannot read a closed stream descriptor")
        return NativeRead(self._state[].descriptor, size, offset)

    def close(self) raises:
        if not self.is_open():
            return
        var descriptor = self._state[].descriptor
        self._state[].descriptor = -1
        if self._state[].owned and external_call["close", c_int](c_int(descriptor)) != 0:
            raise Error("Unable to close stream: ", get_errno())

    def flush(self) raises:
        if not self.is_open():
            raise Error("Cannot flush a closed stream")
        if external_call["fsync", c_int](c_int(self._state[].descriptor)) != 0:
            raise Error("Unable to flush stream: ", get_errno())

    def read(
        self, size: Int, offset: Optional[Int64]
    ) raises -> Optional[Buffer]:
        if not self.is_open():
            return None
        var bytes = List[Byte](capacity=size)
        for _ in range(size):
            bytes.append(0)
        var count = external_call["tsonic_node_stream_read", Int64](
            c_int(self._state[].descriptor),
            bytes.unsafe_ptr(),
            c_size_t(size),
            offset.value() if offset else Int64(0),
            c_int(Bool(offset)),
        )
        if count < 0:
            raise Error("Unable to read stream: ", get_errno())
        if count == 0:
            return None
        while len(bytes) > Int(count):
            _ = bytes.pop()
        return Buffer(bytes^)

    def write(self, value: Buffer, offset: Optional[Int64]) raises -> Int64:
        if not self.is_open():
            raise Error("Cannot write to a closed stream")
        var bytes = value.copy_bytes()
        var count = Int64(0)
        while count < Int64(len(bytes)):
            var written = external_call["tsonic_node_stream_write", Int64](
                c_int(self._state[].descriptor),
                bytes.unsafe_ptr().unsafe_offset(Int(count)),
                c_size_t(len(bytes) - Int(count)),
                offset.value() + count if offset else Int64(0),
                c_int(Bool(offset)),
            )
            if written <= 0:
                raise Error("Unable to write stream: ", get_errno())
            count += written
            self._state[].bytes_written += written
        return count
