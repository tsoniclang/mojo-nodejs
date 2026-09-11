from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable, TsError
from ..internal.network_endpoint import AddressInfo, NetworkEndpoint
from ..internal.typed_listeners import TypedListeners
from ..net.options import ListenOptions
from .socket import (
    EmptyCallback,
    SocketCallback,
    TLSSocket,
    ClientErrorListeners,
)
from .events import require_event
from .state import _TlsServerNativeState

comptime _MAX_SERVERS = 1024


struct _TlsServerState:
    var native: ArcPointer[_TlsServerNativeState]
    var endpoint: Optional[NetworkEndpoint]
    var listen_callback: Optional[EmptyCallback]
    var listen_callback_pending: Bool
    var active: Bool
    var referenced: Bool
    var allow_half_open: Bool
    var handshake_timeout: Float64
    var close_pending: Bool
    var registered: Bool
    var clients: List[TLSSocket]
    var tls_client_errors: ClientErrorListeners
    var errors: TypedListeners[Tuple[TsError]]
    var secure_connections: TypedListeners[Tuple[TLSSocket]]
    var listening_events: TypedListeners[Tuple[]]
    var close_events: TypedListeners[Tuple[]]

    def __init__(
        out self,
        native: ArcPointer[_TlsServerNativeState],
    ):
        self.native = native
        self.endpoint = None
        self.listen_callback = None
        self.listen_callback_pending = False
        self.active = False
        self.referenced = True
        self.allow_half_open = False
        self.handshake_timeout = 120000
        self.close_pending = False
        self.registered = False
        self.clients = List[TLSSocket]()
        self.tls_client_errors = ClientErrorListeners()
        self.errors = TypedListeners[Tuple[TsError]]()
        self.secure_connections = TypedListeners[Tuple[TLSSocket]]()
        self.listening_events = TypedListeners[Tuple[]]()
        self.close_events = TypedListeners[Tuple[]]()


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[_TlsServerState]

    def __init__(
        out self,
        native: ArcPointer[_TlsServerNativeState],
    ):
        self._state = ArcPointer(_TlsServerState(native))

    def listen_default_host(
        self, port: Float64, callback: Optional[EmptyCallback] = None
    ) raises -> Self:
        return self.listen(port, "", callback)

    def listen(
        self,
        port: Float64,
        host: String,
        callback: Optional[EmptyCallback] = None,
    ) raises -> Self:
        return self.listen_host_backlog(port, host, 511, callback)

    def listen_options(self, options: ListenOptions, callback: Optional[EmptyCallback] = None) raises -> Self:
        if not options.port:
            raise Error("TLS listen options require a port")
        return self.listen_host_backlog(options.port.value(), options.host.value() if options.host else "", options.backlog.value() if options.backlog else 511, callback)

    def listen_backlog(self, port: Float64, backlog: Float64, callback: Optional[EmptyCallback] = None) raises -> Self:
        return self.listen_host_backlog(port, "", backlog, callback)

    def listen_host_backlog(self, port: Float64, host: String, backlog: Float64, callback: Optional[EmptyCallback] = None) raises -> Self:
        if self._state[].active:
            raise Error("TLS server is already listening")
        if host.find("\0") >= 0:
            raise Error("TLS host contains a null byte")
        var endpoint = NetworkEndpoint(host, port, True, backlog)
        self._register()
        self._state[].endpoint = endpoint
        self._state[].listen_callback = callback
        self._state[].listen_callback_pending = True
        self._state[].active = True
        self._state[].referenced = True
        self._state[].close_pending = False
        return self

    def close(self) raises -> Self:
        self._register()
        if self._state[].endpoint:
            self._state[].endpoint.value().close()
        self._state[].endpoint = None
        self._state[].active = False
        self._state[].listen_callback_pending = False
        self._state[].listen_callback = None
        self._state[].close_pending = True
        return self

    def _register(self) raises:
        if self._state[].registered:
            return
        if len(_servers.get()[]) >= _MAX_SERVERS:
            prune_servers()
        if len(_servers.get()[]) >= _MAX_SERVERS:
            raise Error("TLS servers exceed the finite runtime limit")
        self._state[].registered = True
        _servers.get()[].append(self)

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def unref(self) -> Self:
        self._state[].referenced = False
        return self

    def listening(self) -> Bool:
        return (
            self._state[].active
            and self._state[].endpoint.value().progress() == 1
        )

    def address(self) raises -> Optional[AddressInfo]:
        return (
            self._state[]
            .endpoint.value()
            .address() if self._state[]
            .endpoint else Optional[AddressInfo]()
        )

    def on_tls_client_error(
        self,
        event: String,
        callback: RaisingCallable[Tuple[TsError, TLSSocket], NoneType],
    ) raises -> Self:
        require_event(event, "tlsClientError")
        self._state[].tls_client_errors.add(callback)
        return self

    def once_tls_client_error(
        self,
        event: String,
        callback: RaisingCallable[Tuple[TsError, TLSSocket], NoneType],
    ) raises -> Self:
        require_event(event, "tlsClientError")
        self._state[].tls_client_errors.add(callback, True)
        return self

    def off_tls_client_error(
        self,
        event: String,
        callback: RaisingCallable[Tuple[TsError, TLSSocket], NoneType],
    ) raises -> Self:
        require_event(event, "tlsClientError")
        self._state[].tls_client_errors.remove(callback)
        return self

    def on_connection(
        self, event: String, callback: SocketCallback
    ) raises -> Self:
        require_event(event, "secureConnection")
        self._state[].secure_connections.add(callback)
        return self

    def once_connection(
        self, event: String, callback: SocketCallback
    ) raises -> Self:
        require_event(event, "secureConnection")
        self._state[].secure_connections.add(callback, True)
        return self

    def off_connection(
        self, event: String, callback: SocketCallback
    ) raises -> Self:
        require_event(event, "secureConnection")
        self._state[].secure_connections.remove(callback)
        return self

    def on_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].errors.add(callback)
        return self

    def once_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].errors.add(callback, True)
        return self

    def off_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].errors.remove(callback)
        return self

    def on_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._empty_event(event).add(callback)
        return self

    def once_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._empty_event(event).add(callback, True)
        return self

    def off_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._empty_event(event).remove(callback)
        return self

    def _empty_event(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event == "listening":
            return self._state[].listening_events
        if event == "close":
            return self._state[].close_events
        raise Error("Unsupported TLS server event: " + event)


def _initial_servers() -> List[Server]:
    return List[Server]()


comptime _servers = GlobalCell["tsonic.node.tls.servers", _initial_servers]()


def prune_servers():
    var retained = List[Server]()
    for server in _servers.get()[]:
        if (
            server._state[].active
            or server._state[].close_pending
            or len(server._state[].clients) != 0
        ):
            retained.append(server)
        else:
            server._state[].registered = False
    _servers.get()[] = retained^
