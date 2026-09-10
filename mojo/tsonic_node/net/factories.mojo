from std.ffi import c_int, external_call
from tsonic_runtime import RaisingCallable
from ..internal.network_endpoint import NetworkEndpoint
from .options import ConnectionOptions, ServerOptions, timeout_duration
from .server import ConnectionCallback, EmptyCallback, Server
from .socket import Socket


def create_connection(port: Float64) raises -> Socket:
    return create_connection_host(port, "localhost")


def create_connection_host(port: Float64, host: String) raises -> Socket:
    return Socket(NetworkEndpoint(host, port, False))


def create_connection_callback(port: Float64, callback: EmptyCallback) raises -> Socket:
    return create_connection_host_callback(port, "localhost", callback)


def create_connection_host_callback(port: Float64, host: String, callback: EmptyCallback) raises -> Socket:
    var socket = create_connection_host(port, host)
    _ = socket.once_empty("connect", callback)
    return socket


def create_connection_options(options: ConnectionOptions) raises -> Socket:
    var host = options.host.value() if options.host else "localhost"
    var timeout = timeout_duration(options.timeout.value()) if options.timeout else 0.0
    var socket = Socket(NetworkEndpoint(host, options.port, False), False,
                        options.allow_half_open.value() if options.allow_half_open else False)
    if options.no_delay:
        _ = socket.set_no_delay(options.no_delay.value())
    if options.timeout:
        _ = socket.set_timeout(timeout)
    return socket


def create_connection_options_callback(options: ConnectionOptions, callback: EmptyCallback) raises -> Socket:
    var socket = create_connection_options(options)
    _ = socket.once_empty("connect", callback)
    return socket


def create_server() -> Server:
    return Server()


def create_server_callback(callback: ConnectionCallback) raises -> Server:
    var server = Server()
    _ = server.on_connection("connection", callback)
    return server


def create_server_options(options: ServerOptions) -> Server:
    return Server(options)


def create_server_options_callback(options: ServerOptions, callback: ConnectionCallback) raises -> Server:
    var server = Server(options)
    _ = server.on_connection("connection", callback)
    return server


def is_ip(value: String) -> Float64:
    if value.find("\0") >= 0:
        return 0
    return Float64(external_call["tsonic_node_is_ip", c_int](
        value.as_c_string_slice().ptr().as_unsafe_any_origin(),
    ))


def is_ipv4(value: String) -> Bool:
    return is_ip(value) == 4


def is_ipv6(value: String) -> Bool:
    return is_ip(value) == 6
