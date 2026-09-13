from std.collections import List
from std.ffi import c_int, external_call
from std.sys._libc import close
from tsonic_runtime import error_new
from ..internal.network_endpoint import (
    network_error,
    poll_network_resolution,
    monotonic_milliseconds,
)
from .socket import TLSSocket, _activities, prune_sockets
from .server import Server, _servers, prune_servers
from .native import _socket_readable, _take_error
from .progress import progress_socket

comptime _MAX_PENDING = 1 << 20


def has_active_tls() -> Bool:
    for socket in _activities.get()[]:
        if socket._state[].failure or (
            socket.closed() and not socket._state[].close_notified
        ):
            return True
        if socket._state[].referenced and not socket.closed():
            return True
    for server in _servers.get()[]:
        if server._state[].close_pending:
            return True
        if server._state[].active and server._state[].referenced:
            return True
    return False


def _accept(server: Server) raises -> Bool:
    var readiness = server._state[].endpoint.value().progress()
    if readiness < 0:
        _ = server.close()
        var failure = network_error(readiness)
        if not server._state[].errors.has_listeners():
            raise failure^
        _ = server._state[].errors.emit((error_new(String(failure)),))
        return True
    if readiness == 0:
        return False
    var worked = False
    if server._state[].listen_callback_pending:
        server._state[].listen_callback_pending = False
        if server._state[].listen_callback:
            var callback = server._state[].listen_callback.take()
            callback.call(())
        _ = server._state[].listening_events.emit(())
        worked = True
    if not server._state[].active or not _socket_readable(
        server._state[].endpoint.value().descriptor()
    ):
        return worked
    var status = c_int(0)
    var descriptor = external_call["tsonic_node_socket_accept", c_int](
        server._state[].endpoint.value().descriptor(), Pointer(to=status)
    )
    if descriptor == -2:
        return worked
    if descriptor < 0:
        raise Error("Unable to accept TLS connection")
    if len(_activities.get()[]) >= _MAX_PENDING:
        prune_sockets()
    if len(_activities.get()[]) >= _MAX_PENDING:
        _ = close(descriptor)
        raise Error("Pending TLS connections exceed the finite runtime limit")
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_server_accept",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        server._state[].native[].handle.value(),
        descriptor,
        Pointer(to=error),
    )
    if not handle:
        raise Error(_take_error(error, "TLS server handshake failed"))
    var socket = TLSSocket(handle)
    socket._state[].server_connections = server._state[].secure_connections
    socket._state[].server_errors = server._state[].tls_client_errors
    socket._state[].native_owner = server._state[].native
    socket._state[].allow_half_open = server._state[].allow_half_open
    if server._state[].handshake_timeout > 0:
        socket._state[].handshake_deadline = (
            monotonic_milliseconds() + server._state[].handshake_timeout
        )
    server._state[].clients.append(socket)
    return True


def poll_tls() raises -> Bool:
    var did_work = poll_network_resolution()
    var servers = _servers.get()[].copy()
    for server in servers:
        if server._state[].active:
            did_work = _accept(server) or did_work
    var sockets = _activities.get()[].copy()
    for socket in sockets:
        did_work = progress_socket(socket) or did_work
    for server in servers:
        var retained = List[TLSSocket]()
        for socket in server._state[].clients:
            if not socket.closed():
                retained.append(socket)
        server._state[].clients = retained^
        if server._state[].close_pending and len(server._state[].clients) == 0:
            server._state[].close_pending = False
            _ = server._state[].close_events.emit(())
            did_work = True
    prune_sockets()
    prune_servers()
    return did_work
