from std.collections import List
from std.ffi import c_int, external_call
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable

from .messages import IncomingMessage, ServerResponse
from .connections import (
    accept_connection,
    has_pending_connections,
    poll_connections,
)
from .transport import HttpTransport
from ..internal.network_endpoint import (
    NetworkEndpoint,
    network_error,
    poll_network_resolution,
)
from ..net.options import ListenOptions


comptime RequestArguments = Tuple[IncomingMessage, ServerResponse]
comptime RequestHandler = RaisingCallable[RequestArguments, NoneType]
comptime ListenCallback = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct ServerState:
    var endpoint: Optional[NetworkEndpoint]
    var handler: RequestHandler
    var listening_callback: Optional[ListenCallback]
    var listening_callback_pending: Bool
    var active: Bool
    var referenced: Bool


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[ServerState]

    def __init__(out self, handler: RequestHandler):
        self._state = ArcPointer(
            ServerState(None, handler, None, False, False, True)
        )

    def listen_default_host(
        self,
        port: Float64,
        callback: Optional[ListenCallback] = None,
    ) raises -> Self:
        return self.listen(port, "", callback)

    def listen_options(
        self, options: ListenOptions, callback: Optional[ListenCallback] = None
    ) raises -> Self:
        if not options.port:
            raise Error("HTTP listen options require a port")
        return self.listen_host_backlog(
            options.port.value(),
            options.host.value() if options.host else "",
            options.backlog.value() if options.backlog else 511,
            callback,
        )

    def listen_backlog(
        self,
        port: Float64,
        backlog: Float64,
        callback: Optional[ListenCallback] = None,
    ) raises -> Self:
        return self.listen_host_backlog(port, "", backlog, callback)

    def listen(
        self,
        port: Float64,
        host: String,
        callback: Optional[ListenCallback] = None,
    ) raises -> Self:
        return self.listen_host_backlog(port, host, 511, callback)

    def listen_host_backlog(
        self,
        port: Float64,
        host: String,
        backlog: Float64,
        callback: Optional[ListenCallback] = None,
    ) raises -> Self:
        if self._state[].active:
            raise Error("HTTP server is already listening")
        var retained = List[Server]()
        for server in _servers.get()[]:
            if server._state[].active:
                retained.append(server)
        _servers.get()[] = retained^
        if len(_servers.get()[]) >= _max_servers:
            raise Error("Active HTTP servers exceed the finite runtime limit")
        if host.find("\0") >= 0:
            raise Error("HTTP host contains a null byte")
        self._state[].endpoint = NetworkEndpoint(host, port, True, backlog)
        self._state[].listening_callback = callback
        self._state[].listening_callback_pending = True
        self._state[].active = True
        _servers.get()[].append(self)
        return self

    def close(self):
        if self._state[].endpoint:
            self._state[].endpoint.value().close()
        self._state[].endpoint = None
        self._state[].active = False

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def unref(self) -> Self:
        self._state[].referenced = False
        return self


def create_server(handler: RequestHandler) -> Server:
    return Server(handler)


def _initial_servers() -> List[Server]:
    return List[Server]()


comptime _servers = GlobalCell["tsonic.node.http.servers", _initial_servers]()
comptime _max_servers = 1024


def has_active_servers() -> Bool:
    for index in range(len(_servers.get()[])):
        if (
            _servers.get()[][index]._state[].active
            and _servers.get()[][index]._state[].referenced
        ):
            return True
    return has_pending_connections()


def poll_servers() raises -> Bool:
    var did_work = poll_network_resolution()
    var servers = _servers.get()[].copy()
    for server in servers:
        if not server._state[].active:
            continue
        var status = server._state[].endpoint.value().progress()
        if status < 0:
            server.close()
            raise network_error(status)
        if status == 0:
            continue
        if server._state[].listening_callback_pending:
            server._state[].listening_callback_pending = False
            if server._state[].listening_callback:
                server._state[].listening_callback.value().call(())
            did_work = True
        if server._state[].active and _socket_readable(
            server._state[].endpoint.value().descriptor()
        ):
            _accept_request(server)
            did_work = True
    var connection_work = poll_connections()
    return did_work or connection_work


def _accept_request(server: Server) raises:
    var status = c_int(0)
    var descriptor = external_call["tsonic_node_socket_accept", c_int](
        server._state[].endpoint.value().descriptor(), Pointer(to=status)
    )
    if descriptor == -2:
        return
    if descriptor < 0:
        raise Error("Unable to accept HTTP connection")
    accept_connection(HttpTransport(descriptor), server._state[].handler)


def _socket_readable(descriptor: Int32) raises -> Bool:
    var result = external_call["tsonic_node_socket_readable", c_int](descriptor)
    if result < 0:
        raise Error("Unable to poll HTTP server socket")
    return result > 0
