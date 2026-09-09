from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from std.sys._libc import close
from ..buffer import Buffer
from ..tls import TLSSocket


struct _TransportState(Movable):
    var descriptor: Int32
    var tls: Optional[TLSSocket]

    def __init__(out self, descriptor: Int32, tls: Optional[TLSSocket]):
        self.descriptor = descriptor
        self.tls = tls

    def __deinit__(deinit self):
        if self.descriptor >= 0:
            _ = close(self.descriptor)
        if self.tls:
            self.tls.value().destroy()


struct HttpTransport(ImplicitlyCopyable):
    var _state: ArcPointer[_TransportState]

    def __init__(out self, descriptor: Int32):
        self._state = ArcPointer(_TransportState(descriptor, None))

    def __init__(out self, socket: TLSSocket):
        self._state = ArcPointer(_TransportState(-1, Optional(socket)))

    def read_into(self, mut bytes: List[Byte]) raises -> Int:
        if self._state[].tls:
            return self._state[].tls.value().read_into(bytes)
        var count = external_call["tsonic_node_socket_read", Int64](self._state[].descriptor, bytes.unsafe_ptr(), c_size_t(len(bytes)))
        if count == -1:
            raise Error("Unable to read HTTP connection")
        return Int(count)

    def write_some(self, bytes: List[Byte], offset: Int) raises -> Int:
        var count = min(len(bytes) - offset, 65536)
        if count <= 0:
            return 0
        if self._state[].tls:
            var socket = self._state[].tls.value()
            socket.progress()
            if socket.pending():
                return 0
            var chunk = List[Byte](capacity=count)
            for index in range(count):
                chunk.append(bytes[offset + index])
            _ = socket.write_buffer(Buffer(chunk^))
            return count
        var written = external_call["tsonic_node_socket_write", Int64](self._state[].descriptor, bytes.unsafe_ptr().unsafe_offset(offset), c_size_t(count))
        if written == -2:
            return 0
        if written <= 0:
            raise Error("Unable to write HTTP response")
        return Int(written)

    def end(self) raises:
        if self._state[].tls:
            self._state[].tls.value().end()
        elif self._state[].descriptor >= 0:
            _ = close(self._state[].descriptor)
            self._state[].descriptor = -1

    def close(self):
        if self._state[].tls:
            self._state[].tls.value().destroy()
        if self._state[].descriptor >= 0:
            _ = close(self._state[].descriptor)
            self._state[].descriptor = -1

    def closed(self) -> Bool:
        return self._state[].tls.value().closed() if self._state[].tls else self._state[].descriptor < 0
