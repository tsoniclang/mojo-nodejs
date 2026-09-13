from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from .options import ConnectionOptions, TlsOptions
from .socket import EmptyCallback, SocketCallback, TLSSocket
from .server import Server
from .state import _TlsServerNativeState
from .native import _alpn_wire, _port, _take_error
from .secure_context import create_secure_context
from ..net.options import timeout_duration


def connect(options: ConnectionOptions) raises -> TLSSocket:
    var host = options.host.value() if options.host else "localhost"
    var servername = options.servername.value() if options.servername else ""
    var verification_name = (
        servername if servername.byte_length() != 0 else host
    )
    if host.find("\0") >= 0 or servername.find("\0") >= 0:
        raise Error("TLS host contains a null byte")
    var port = _port(options.port.value() if options.port else 443)
    var reject = (
        options.reject_unauthorized.value() if options.reject_unauthorized else True
    )
    var context = options.secure_context.value() if options.secure_context else create_secure_context(
        options.context_options()
    )
    var alpn = _alpn_wire(options.alpn_protocols)
    var timeout = timeout_duration(
        options.timeout.value()
    ) if options.timeout else 0.0
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_connect",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        context._state[].handle,
        host.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin(),
        verification_name.as_c_string_slice()
        .unsafe_ptr()
        .as_unsafe_any_origin(),
        servername.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin(),
        c_int(port),
        c_int(reject),
        alpn.unsafe_ptr(),
        c_size_t(len(alpn)),
        Pointer(to=error),
    )
    if not handle:
        raise Error(_take_error(error, "Unable to establish TLS connection"))
    var socket = TLSSocket(handle)
    socket._state[].allow_half_open = (
        options.allow_half_open.value() if options.allow_half_open else False
    )
    _ = socket.set_timeout(timeout)
    return socket^


def connect_callback(
    options: ConnectionOptions, callback: EmptyCallback
) raises -> TLSSocket:
    var socket = connect(options)
    _ = socket.once_empty("secureConnect", callback)
    return socket^


def create_server(
    options: TlsOptions, callback: Optional[SocketCallback] = None
) raises -> Server:
    var handshake_timeout = timeout_duration(
        options.handshake_timeout.value()
    ) if options.handshake_timeout else 120000.0
    var context = create_secure_context(options.context_options())
    var alpn = _alpn_wire(options.alpn_protocols)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_server_create",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        context._state[].handle,
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
    var server = Server(ArcPointer(_TlsServerNativeState(handle)))
    if callback:
        server._state[].secure_connections.add(callback.value())
    server._state[].allow_half_open = (
        options.allow_half_open.value() if options.allow_half_open else False
    )
    server._state[].handshake_timeout = handshake_timeout
    return server^
