from std.collections import List
from std.ffi import c_int, c_size_t, c_ssize_t, c_ulong, external_call
from std.memory import ArcPointer
from std.sys._libc import close
from tsonic_runtime import GlobalCell, RaisingCallable

from .buffer import Buffer


comptime EmptyCallback = RaisingCallable[Tuple[], NoneType]
comptime SocketCallback = RaisingCallable[Tuple[TLSSocket], NoneType]

comptime _MAX_SERVERS = 1024
comptime _MAX_PENDING = 1 << 20


struct ConnectionOptions(Copyable):
    var host: Optional[String]
    var servername: Optional[String]
    var port: Optional[Float64]
    var alpn_protocols: Optional[List[String]]
    var reject_unauthorized: Optional[Bool]
    var ca: Optional[List[String]]
    var timeout: Optional[Float64]

    def __init__(
        out self,
        host: Optional[String] = None,
        servername: Optional[String] = None,
        port: Optional[Float64] = None,
        var alpn_protocols: Optional[List[String]] = None,
        reject_unauthorized: Optional[Bool] = None,
        var ca: Optional[List[String]] = None,
        timeout: Optional[Float64] = None,
    ):
        self.host = host
        self.servername = servername
        self.port = port
        self.alpn_protocols = alpn_protocols^
        self.reject_unauthorized = reject_unauthorized
        self.ca = ca^
        self.timeout = timeout


struct TlsOptions(Copyable):
    var key: Optional[String]
    var cert: Optional[String]
    var ca: Optional[List[String]]
    var alpn_protocols: Optional[List[String]]
    var request_cert: Optional[Bool]
    var reject_unauthorized: Optional[Bool]

    def __init__(
        out self,
        key: Optional[String] = None,
        cert: Optional[String] = None,
        var ca: Optional[List[String]] = None,
        var alpn_protocols: Optional[List[String]] = None,
        request_cert: Optional[Bool] = None,
        reject_unauthorized: Optional[Bool] = None,
    ):
        self.key = key
        self.cert = cert
        self.ca = ca^
        self.alpn_protocols = alpn_protocols^
        self.request_cert = request_cert
        self.reject_unauthorized = reject_unauthorized


struct _TlsSocketState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var referenced: Bool

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle
        self.referenced = True

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_tls_socket_free", NoneType](
                self.handle.value()
            )


struct TLSSocket(ImplicitlyCopyable):
    var _state: ArcPointer[_TlsSocketState]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ) raises:
        if not handle:
            raise Error("TLS socket handle is absent")
        self._state = ArcPointer(_TlsSocketState(handle))

    def write_buffer(self, value: Buffer) raises -> Bool:
        var bytes = value.copy_bytes()
        if len(bytes) == 0:
            return True
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var written = external_call["tsonic_node_tls_write", Int64](
            self._handle(),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            Pointer(to=error),
        )
        if written < 0 or written != Int64(len(bytes)):
            raise Error(_take_error(error, "TLS write failed"))
        return True

    def write_string(self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def read(self) raises -> Optional[Buffer]:
        var bytes = List[Byte](capacity=65536)
        for _ in range(65536):
            bytes.append(Byte(0))
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var count = external_call["tsonic_node_tls_read", Int64](
            self._handle(),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            Pointer(to=error),
        )
        if count < 0:
            raise Error(_take_error(error, "TLS read failed"))
        if count == 0:
            return None
        var result = List[Byte](capacity=Int(count))
        for index in range(Int(count)):
            result.append(bytes[index])
        return Optional(Buffer(result^))

    def end(self) raises:
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        if (
            external_call["tsonic_node_tls_end", c_int](
                self._handle(), Pointer(to=error)
            )
            == 0
        ):
            raise Error(_take_error(error, "Unable to close TLS socket"))

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def unref(self) -> Self:
        self._state[].referenced = False
        return self

    def authorized(self) -> Bool:
        return Bool(
            external_call["tsonic_node_tls_authorized", c_int](self._handle())
        )

    def authorization_error(self) -> Optional[String]:
        var value = external_call[
            "tsonic_node_tls_authorization_error",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        return Optional(
            String(unsafe_from_utf8_ptr=value.value())
        ) if value else None

    def encrypted(self) -> Bool:
        return True

    def servername_value(self) -> String:
        var value = external_call[
            "tsonic_node_tls_servername",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        return String(unsafe_from_utf8_ptr=value.value()) if value else ""

    def alpn_protocol(self) -> Optional[String]:
        var value = external_call[
            "tsonic_node_tls_alpn",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        return Optional(
            String(unsafe_from_utf8_ptr=value.value())
        ) if value else None

    def bytes_read(self) -> Float64:
        return Float64(
            external_call["tsonic_node_tls_bytes_read", UInt64](self._handle())
        )

    def bytes_written(self) -> Float64:
        return Float64(
            external_call["tsonic_node_tls_bytes_written", UInt64](
                self._handle()
            )
        )

    def _handle(self) -> Pointer[NoneType, MutUntrackedOrigin]:
        return self._state[].handle.value()


struct _TlsServerNativeState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_tls_server_free", NoneType](
                self.handle.value()
            )


struct _TlsServerState:
    var native: ArcPointer[_TlsServerNativeState]
    var callback: SocketCallback
    var descriptor: Int32
    var listen_callback: Optional[EmptyCallback]
    var listen_callback_pending: Bool
    var active: Bool
    var referenced: Bool

    def __init__(
        out self,
        native: ArcPointer[_TlsServerNativeState],
        callback: SocketCallback,
    ):
        self.native = native
        self.callback = callback
        self.descriptor = -1
        self.listen_callback = None
        self.listen_callback_pending = False
        self.active = False
        self.referenced = True


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[_TlsServerState]

    def __init__(
        out self,
        native: ArcPointer[_TlsServerNativeState],
        callback: SocketCallback,
    ):
        self._state = ArcPointer(_TlsServerState(native, callback))

    def listen_default_host(
        self, port: Float64, callback: EmptyCallback
    ) raises -> Self:
        return self.listen(port, "0.0.0.0", callback)

    def listen(
        self, port: Float64, host: String, callback: EmptyCallback
    ) raises -> Self:
        if self._state[].active:
            raise Error("TLS server is already listening")
        var host_buffer = String(host)
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var descriptor = external_call["tsonic_node_net_listen", c_int](
            host_buffer.as_c_string_slice().ptr().as_unsafe_any_origin(),
            c_int(_port(port)),
            Pointer(to=error),
        )
        if descriptor < 0:
            raise Error(
                _take_error(error, "Unable to listen for TLS connections")
            )
        if len(_servers.get()[]) >= _MAX_SERVERS:
            _ = close(descriptor)
            raise Error("TLS servers exceed the finite runtime limit")
        self._state[].descriptor = descriptor
        self._state[].listen_callback = Optional(callback)
        self._state[].listen_callback_pending = True
        self._state[].active = True
        self._state[].referenced = True
        _servers.get()[].append(self)
        return self

    def close(self):
        if self._state[].descriptor >= 0:
            _ = close(self._state[].descriptor)
        self._state[].descriptor = -1
        self._state[].active = False

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def unref(self) -> Self:
        self._state[].referenced = False
        return self

    def listening(self) -> Bool:
        return self._state[].active


@fieldwise_init
struct _PendingConnect(ImplicitlyCopyable):
    var callback: EmptyCallback


def _initial_servers() -> List[Server]:
    return List[Server]()


def _initial_connects() -> List[_PendingConnect]:
    return List[_PendingConnect]()


comptime _servers = GlobalCell["tsonic.node.tls.servers", _initial_servers]()
comptime _pending_connects = GlobalCell[
    "tsonic.node.tls.connects", _initial_connects
]()


def connect(options: ConnectionOptions) raises -> TLSSocket:
    var host = options.host.value() if options.host else "localhost"
    var servername = options.servername.value() if options.servername else host
    var port = _port(options.port.value() if options.port else 443)
    var reject = (
        options.reject_unauthorized.value() if options.reject_unauthorized else True
    )
    var ca = _join_certificates(options.ca)
    var alpn = _alpn_wire(options.alpn_protocols)
    var timeout = _milliseconds(
        options.timeout.value()
    ) if options.timeout else -1
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_connect",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        host.as_c_string_slice().ptr().as_unsafe_any_origin(),
        servername.as_c_string_slice().ptr().as_unsafe_any_origin(),
        c_int(port),
        c_int(reject),
        ca.as_c_string_slice().ptr().as_unsafe_any_origin(),
        alpn.unsafe_ptr(),
        c_size_t(len(alpn)),
        c_int(timeout),
        Pointer(to=error),
    )
    if not handle:
        raise Error(_take_error(error, "Unable to establish TLS connection"))
    return TLSSocket(handle)


def connect_callback(
    options: ConnectionOptions, callback: EmptyCallback
) raises -> TLSSocket:
    if len(_pending_connects.get()[]) >= _MAX_PENDING:
        raise Error("Pending TLS callbacks exceed the finite runtime limit")
    var socket = connect(options)
    _pending_connects.get()[].append(_PendingConnect(callback))
    return socket^


def create_server(
    options: TlsOptions, callback: SocketCallback
) raises -> Server:
    if not options.key or not options.cert:
        raise Error("TLS server requires key and cert options")
    var ca = _join_certificates(options.ca)
    var alpn = _alpn_wire(options.alpn_protocols)
    var key = String(options.key.value())
    var certificate = String(options.cert.value())
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_server_create",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        key.as_c_string_slice().ptr().as_unsafe_any_origin(),
        certificate.as_c_string_slice().ptr().as_unsafe_any_origin(),
        ca.as_c_string_slice().ptr().as_unsafe_any_origin(),
        alpn.unsafe_ptr(),
        c_size_t(len(alpn)),
        c_int(options.request_cert.value() if options.request_cert else False),
        c_int(
            options.reject_unauthorized.value() if options.reject_unauthorized else True
        ),
        Pointer(to=error),
    )
    if not handle:
        raise Error(_take_error(error, "Unable to create TLS server"))
    return Server(ArcPointer(_TlsServerNativeState(handle)), callback)


def has_active_tls() -> Bool:
    if len(_pending_connects.get()[]) != 0:
        return True
    for server in _servers.get()[]:
        if server._state[].active and server._state[].referenced:
            return True
    return False


def poll_tls() raises -> Bool:
    var did_work = False
    if len(_pending_connects.get()[]) != 0:
        var pending = List[_PendingConnect]()
        for connect in _pending_connects.get()[]:
            pending.append(connect)
        _pending_connects.get()[] = List[_PendingConnect]()
        for connect in pending:
            connect.callback.call(())
        did_work = True
    for server in _servers.get()[]:
        if not server._state[].active:
            continue
        if server._state[].listen_callback_pending:
            server._state[].listen_callback_pending = False
            if server._state[].listen_callback:
                server._state[].listen_callback.value().call(())
            did_work = True
        if not _socket_readable(server._state[].descriptor):
            continue
        var descriptor = external_call["accept", c_int](
            server._state[].descriptor,
            OptionalPointer[NoneType, MutUntrackedOrigin](),
            OptionalPointer[NoneType, MutUntrackedOrigin](),
        )
        if descriptor < 0:
            continue
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var handle = external_call[
            "tsonic_node_tls_server_accept",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](
            server._state[].native[].handle.value(),
            c_int(descriptor),
            Pointer(to=error),
        )
        if not handle:
            raise Error(_take_error(error, "TLS server handshake failed"))
        server._state[].callback.call((TLSSocket(handle),))
        did_work = True
    return did_work


def _alpn_wire(protocols: Optional[List[String]]) raises -> List[Byte]:
    var output = List[Byte]()
    if not protocols:
        output.append(Byte(0))
        _ = output.pop()
        return output^
    for protocol in protocols.value():
        var length = protocol.byte_length()
        if length == 0 or length > 255:
            raise Error(
                "Each ALPN protocol must contain 1 through 255 UTF-8 bytes"
            )
        output.append(Byte(UInt8(length)))
        for byte in protocol.as_bytes():
            output.append(byte)
    return output^


def _join_certificates(certificates: Optional[List[String]]) -> String:
    if not certificates:
        return ""
    var result = String()
    for certificate in certificates.value():
        if result.byte_length() != 0:
            result += "\n"
        result += certificate
    return result^


def _port(value: Float64) raises -> Int32:
    var port = Int(value)
    if Float64(port) != value or port < 0 or port > 65535:
        raise Error("TLS port must be an integer from 0 through 65535")
    return Int32(port)


def _milliseconds(value: Float64) raises -> Int32:
    var milliseconds = Int(value)
    if (
        Float64(milliseconds) != value
        or milliseconds < 0
        or milliseconds > 2147483647
    ):
        raise Error("TLS timeout must be a non-negative 32-bit integer")
    return Int32(milliseconds)


def _socket_readable(descriptor: Int32) raises -> Bool:
    var poll_data = Array[Int32, 2](fill=0)
    poll_data[0] = descriptor
    poll_data[1] = 1
    var result = external_call["poll", c_int](
        poll_data.unsafe_ptr(), c_ulong(1), c_int(0)
    )
    if result < 0:
        raise Error("Unable to poll TLS server socket")
    return result > 0 and ((poll_data[1] >> 16) & 1) == 1


def _take_error(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin], fallback: String
) -> String:
    if not pointer:
        return fallback
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^
