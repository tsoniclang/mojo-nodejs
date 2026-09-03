from std.collections import List
from std.ffi import c_int, c_size_t, c_ssize_t, c_ulong, external_call
from std.memory import ArcPointer
from std.sys._libc import close
from tsonic_runtime import GlobalCell, RaisingCallable

from .buffer import Buffer


alias EmptyCallback = RaisingCallable[Tuple[], NoneType]
alias ConnectionCallback = RaisingCallable[Tuple[Socket], NoneType]


@fieldwise_init
struct _SocketState:
    var descriptor: Int32
    var bytes_read: Int
    var bytes_written: Int
    var destroyed: Bool
    var pending: Bool
    var referenced: Bool
    var paused: Bool


struct Socket(ImplicitlyCopyable):
    var _state: ArcPointer[_SocketState]

    def __init__(out self, descriptor: Int32, pending: Bool = False):
        self._state = ArcPointer(
            _SocketState(descriptor, 0, 0, False, pending, True, False)
        )

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        self._require_open()
        var bytes = value.copy_bytes()
        var offset = 0
        while offset < len(bytes):
            var written = external_call["send", c_ssize_t](
                self._state[].descriptor,
                bytes.unsafe_ptr().unsafe_offset(offset),
                c_size_t(len(bytes) - offset),
                c_int(0),
            )
            if written <= 0:
                raise Error("Unable to write network socket")
            offset += written
            self._state[].bytes_written += written
        return True

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def read(mut self) raises -> Buffer:
        self._require_open()
        var bytes = List[Byte](capacity=64 * 1024)
        for _ in range(64 * 1024):
            bytes.append(0)
        var count = external_call["recv", c_ssize_t](
            self._state[].descriptor,
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            c_int(0),
        )
        if count < 0:
            raise Error("Unable to read network socket")
        var result = List[Byte](capacity=count)
        for index in range(count):
            result.append(bytes[index])
        self._state[].bytes_read += count
        return Buffer(result^)

    def end(mut self) raises:
        self._require_open()
        if external_call["shutdown", c_int](
            self._state[].descriptor, c_int(1)
        ) != 0:
            raise Error("Unable to end network socket")

    def end_buffer(mut self, value: Buffer) raises:
        _ = self.write_buffer(value)
        self.end()

    def end_string(mut self, value: String) raises:
        _ = self.write_string(value)
        self.end()

    def destroy(mut self):
        if not self._state[].destroyed:
            _ = close(self._state[].descriptor)
        self._state[].descriptor = -1
        self._state[].destroyed = True
        self._state[].pending = False

    def ref(mut self) -> Self:
        self._state[].referenced = True
        return self

    def unref(mut self) -> Self:
        self._state[].referenced = False
        return self

    def pause(mut self) -> Self:
        self._state[].paused = True
        return self

    def resume(mut self) -> Self:
        self._state[].paused = False
        return self

    def set_no_delay(mut self, value: Bool) raises -> Self:
        self._require_open()
        if external_call["tsonic_node_net_set_no_delay", c_int](
            self._state[].descriptor, c_int(value)
        ) != 0:
            raise Error("Unable to set network no-delay state")
        return self

    def set_timeout(mut self, timeout: Float64) raises -> Self:
        self._require_open()
        if timeout < 0 or timeout != timeout or timeout == FloatLiteral.infinity:
            raise Error("Socket timeout must be a finite non-negative number")
        if external_call["tsonic_node_net_set_timeout", c_int](
            self._state[].descriptor, c_int(Int(timeout))
        ) != 0:
            raise Error("Unable to set network socket timeout")
        return self

    def bytes_read(self) -> Float64:
        return Float64(self._state[].bytes_read)

    def bytes_written(self) -> Float64:
        return Float64(self._state[].bytes_written)

    def destroyed(self) -> Bool:
        return self._state[].destroyed

    def pending(self) -> Bool:
        return self._state[].pending

    def _require_open(self) raises:
        if self._state[].destroyed or self._state[].descriptor < 0:
            raise Error("Network socket is closed")


@fieldwise_init
struct _ServerState:
    var descriptor: Int32
    var connection_callback: Optional[ConnectionCallback]
    var listen_callback: Optional[EmptyCallback]
    var listen_callback_pending: Bool
    var listening: Bool
    var referenced: Bool


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[_ServerState]

    def __init__(out self):
        self._state = ArcPointer(
            _ServerState(-1, None, None, False, False, True)
        )

    def __init__(out self, callback: ConnectionCallback):
        self._state = ArcPointer(
            _ServerState(
                -1,
                Optional[ConnectionCallback](callback),
                None,
                False,
                False,
                True,
            )
        )

    def listen_port(mut self, port: Float64) raises -> Self:
        return self._listen(port, "0.0.0.0", None)

    def listen_port_host(
        mut self, port: Float64, host: String
    ) raises -> Self:
        return self._listen(port, host, None)

    def listen_port_callback(
        mut self, port: Float64, callback: EmptyCallback
    ) raises -> Self:
        return self._listen(
            port, "0.0.0.0", Optional[EmptyCallback](callback)
        )

    def listen_port_host_callback(
        mut self,
        port: Float64,
        host: String,
        callback: EmptyCallback,
    ) raises -> Self:
        return self._listen(port, host, Optional[EmptyCallback](callback))

    def close(mut self):
        if self._state[].descriptor >= 0:
            _ = close(self._state[].descriptor)
        self._state[].descriptor = -1
        self._state[].listening = False
        self._state[].listen_callback_pending = False

    def ref(mut self) -> Self:
        self._state[].referenced = True
        return self

    def unref(mut self) -> Self:
        self._state[].referenced = False
        return self

    def listening(self) -> Bool:
        return self._state[].listening

    def _listen(
        mut self,
        port: Float64,
        host: String,
        callback: Optional[EmptyCallback],
    ) raises -> Self:
        if self._state[].listening:
            raise Error("Network server is already listening")
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var descriptor = external_call["tsonic_node_net_listen", c_int](
            host.as_c_string_slice().ptr().as_unsafe_any_origin(),
            c_int(Int(port)),
            Pointer(to=error),
        )
        if descriptor < 0:
            raise Error(_take_error(error, "Unable to listen"))
        self._state[].descriptor = descriptor
        self._state[].listen_callback = callback
        self._state[].listen_callback_pending = Bool(callback)
        self._state[].listening = True
        _register_server(self)
        return self


@fieldwise_init
struct _PendingConnection:
    var callback: EmptyCallback


def _initial_servers() -> List[Server]:
    return List[Server]()


def _initial_connections() -> List[_PendingConnection]:
    return List[_PendingConnection]()


comptime _servers = GlobalCell[
    "tsonic.node.net.servers", _initial_servers
]()
comptime _pending_connections = GlobalCell[
    "tsonic.node.net.pending-connections", _initial_connections
]()
comptime _server_limit = 1024
comptime _pending_limit = 1 << 20


def create_connection(port: Float64) raises -> Socket:
    return create_connection_host(port, "localhost")


def create_connection_host(port: Float64, host: String) raises -> Socket:
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var descriptor = external_call["tsonic_node_net_connect", c_int](
        host.as_c_string_slice().ptr().as_unsafe_any_origin(),
        c_int(Int(port)),
        Pointer(to=error),
    )
    if descriptor < 0:
        raise Error(_take_error(error, "Unable to connect"))
    return Socket(descriptor)


def create_connection_callback(
    port: Float64, callback: EmptyCallback
) raises -> Socket:
    return create_connection_host_callback(port, "localhost", callback)


def create_connection_host_callback(
    port: Float64,
    host: String,
    callback: EmptyCallback,
) raises -> Socket:
    if len(_pending_connections.get()[]) >= _pending_limit:
        raise Error("Pending connection callbacks exceed the finite runtime limit")
    var socket = create_connection_host(port, host)
    _pending_connections.get()[].append(_PendingConnection(callback))
    return socket


def create_server() -> Server:
    return Server()


def create_server_callback(callback: ConnectionCallback) -> Server:
    return Server(callback)


def is_ip(value: String) -> Float64:
    return Float64(
        external_call["tsonic_node_is_ip", c_int](
            value.as_c_string_slice().ptr().as_unsafe_any_origin()
        )
    )


def is_ipv4(value: String) -> Bool:
    return is_ip(value) == 4


def is_ipv6(value: String) -> Bool:
    return is_ip(value) == 6


def has_active_net() -> Bool:
    if len(_pending_connections.get()[]) != 0:
        return True
    for server in _servers.get()[]:
        if server._state[].listening and server._state[].referenced:
            return True
    return False


def poll_net() raises -> Bool:
    var did_work = False
    if len(_pending_connections.get()[]) != 0:
        var pending = List[_PendingConnection]()
        for callback in _pending_connections.get()[]:
            pending.append(callback)
        _pending_connections.get()[] = List[_PendingConnection]()
        for connection in pending:
            connection.callback.call(())
        did_work = True
    for server in _servers.get()[]:
        if not server._state[].listening:
            continue
        if server._state[].listen_callback_pending:
            server._state[].listen_callback_pending = False
            if server._state[].listen_callback:
                server._state[].listen_callback.value().call(())
            did_work = True
        if _socket_readable(server._state[].descriptor):
            var descriptor = external_call["accept", c_int](
                server._state[].descriptor,
                OptionalPointer[NoneType, MutUntrackedOrigin](),
                OptionalPointer[NoneType, MutUntrackedOrigin](),
            )
            if descriptor >= 0:
                var socket = Socket(descriptor)
                if server._state[].connection_callback:
                    server._state[].connection_callback.value().call((socket,))
                else:
                    socket.destroy()
                did_work = True
    return did_work


def _register_server(server: Server) raises:
    if len(_servers.get()[]) >= _server_limit:
        raise Error("Network servers exceed the finite runtime limit")
    _servers.get()[].append(server)


def _socket_readable(descriptor: Int32) raises -> Bool:
    var poll_data = Array[Int32, 2](fill=0)
    poll_data[0] = descriptor
    poll_data[1] = 1
    var result = external_call["poll", c_int](
        poll_data.unsafe_ptr(), c_ulong(1), c_int(0)
    )
    if result < 0:
        raise Error("Unable to poll network server socket")
    return result > 0 and ((poll_data[1] >> 16) & 1) == 1


def _take_error(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin],
    fallback: String,
) -> String:
    if not pointer:
        return fallback
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^
