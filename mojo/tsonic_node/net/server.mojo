from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable, TsError, error_new
from ..internal.network_endpoint import (
    AddressInfo,
    NetworkEndpoint,
    network_error,
)
from ..internal.typed_listeners import TypedListeners
from .options import ListenOptions, ServerOptions
from .socket import Socket


comptime EmptyCallback = RaisingCallable[Tuple[], NoneType]
comptime ConnectionCallback = RaisingCallable[Tuple[Socket], NoneType]


struct _ServerState(Movable):
    var endpoint: Optional[NetworkEndpoint]
    var connections: List[Socket]
    var callbacks: TypedListeners[Tuple[Socket]]
    var listeners: TypedListeners[Tuple[]]
    var closes: TypedListeners[Tuple[]]
    var errors: TypedListeners[Tuple[TsError]]
    var options: ServerOptions
    var active: Bool
    var listening: Bool
    var closing: Bool
    var referenced: Bool

    def __init__(out self, var options: ServerOptions):
        self.endpoint = None
        self.connections = List[Socket]()
        self.callbacks = TypedListeners[Tuple[Socket]]()
        self.listeners = TypedListeners[Tuple[]]()
        self.closes = TypedListeners[Tuple[]]()
        self.errors = TypedListeners[Tuple[TsError]]()
        self.options = options^
        self.active = False
        self.listening = False
        self.closing = False
        self.referenced = True


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[_ServerState]

    def __init__(out self, var options: ServerOptions = ServerOptions()):
        self._state = ArcPointer(_ServerState(options^))

    def listen_port(mut self, port: Float64) raises -> Self:
        return self._listen(port, "", None)

    def listen_port_host(mut self, port: Float64, host: String) raises -> Self:
        return self._listen(port, host, None)

    def listen_port_callback(
        mut self, port: Float64, callback: EmptyCallback
    ) raises -> Self:
        return self._listen(port, "", callback)

    def listen_port_host_callback(
        mut self, port: Float64, host: String, callback: EmptyCallback
    ) raises -> Self:
        return self._listen(port, host, callback)

    def listen_options(mut self, options: ListenOptions) raises -> Self:
        return self._listen_options(options, None)

    def listen_options_callback(
        mut self, options: ListenOptions, callback: EmptyCallback
    ) raises -> Self:
        return self._listen_options(options, callback)

    def _listen_options(
        mut self, options: ListenOptions, callback: Optional[EmptyCallback]
    ) raises -> Self:
        if not options.port:
            raise Error("TCP listen options require a port")
        return self._listen(
            options.port.value(),
            options.host.value() if options.host else "",
            callback,
            options.backlog.value() if options.backlog else 511,
        )

    def listen_port_backlog(
        mut self, port: Float64, backlog: Float64
    ) raises -> Self:
        return self._listen(port, "", None, backlog)

    def listen_port_host_backlog(
        mut self, port: Float64, host: String, backlog: Float64
    ) raises -> Self:
        return self._listen(port, host, None, backlog)

    def listen_port_backlog_callback(
        mut self, port: Float64, backlog: Float64, callback: EmptyCallback
    ) raises -> Self:
        return self._listen(port, "", callback, backlog)

    def listen_port_host_backlog_callback(
        mut self,
        port: Float64,
        host: String,
        backlog: Float64,
        callback: EmptyCallback,
    ) raises -> Self:
        return self._listen(port, host, callback, backlog)

    def close(mut self) raises -> Self:
        if not self._state[].active and not self._state[].closing:
            _prune_servers()
            if len(_servers.get()[]) >= 1024:
                raise Error("Network servers exceed the finite runtime limit")
            _servers.get()[].append(self)
        if self._state[].endpoint:
            self._state[].endpoint.value().close()
        self._state[].active = False
        self._state[].listening = False
        self._state[].closing = True
        return self

    def ref(mut self) -> Self:
        self._state[].referenced = True
        return self

    def unref(mut self) -> Self:
        self._state[].referenced = False
        return self

    def listening(self) -> Bool:
        return (
            self._state[].active
            and self._state[].endpoint.value().progress() == 1
        )

    def address(self) raises -> Optional[AddressInfo]:
        if not self._state[].endpoint or not self._state[].active:
            return None
        return self._state[].endpoint.value().address()

    def on_connection(
        mut self, event: String, callback: ConnectionCallback
    ) raises -> Self:
        self._require_event(event, "connection")
        self._state[].callbacks.add(callback)
        return self

    def once_connection(
        mut self, event: String, callback: ConnectionCallback
    ) raises -> Self:
        self._require_event(event, "connection")
        self._state[].callbacks.add(callback, True)
        return self

    def off_connection(
        mut self, event: String, callback: ConnectionCallback
    ) raises -> Self:
        self._require_event(event, "connection")
        self._state[].callbacks.remove(callback)
        return self

    def on_error(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[TsError], NoneType],
    ) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.add(callback)
        return self

    def once_error(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[TsError], NoneType],
    ) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.add(callback, True)
        return self

    def off_error(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[TsError], NoneType],
    ) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.remove(callback)
        return self

    def on_empty(
        mut self, event: String, callback: EmptyCallback
    ) raises -> Self:
        self._empty_event(event).add(callback)
        return self

    def once_empty(
        mut self, event: String, callback: EmptyCallback
    ) raises -> Self:
        self._empty_event(event).add(callback, True)
        return self

    def off_empty(
        mut self, event: String, callback: EmptyCallback
    ) raises -> Self:
        self._empty_event(event).remove(callback)
        return self

    def _empty_event(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event == "listening":
            return self._state[].listeners
        if event == "close":
            return self._state[].closes
        raise Error("Unsupported server event: " + event)

    def _require_event(self, event: String, expected: String) raises:
        if event != expected:
            raise Error(
                "Server event does not match its selected listener: " + event
            )

    def _listen(
        mut self,
        port: Float64,
        host: String,
        callback: Optional[EmptyCallback],
        backlog: Float64 = 511,
    ) raises -> Self:
        if self._state[].active or self._state[].closing:
            raise Error("Network server is already active")
        _prune_servers()
        if len(_servers.get()[]) >= 1024:
            raise Error("Network servers exceed the finite runtime limit")
        var endpoint = NetworkEndpoint(host, port, True, backlog)
        if callback:
            self._state[].listeners.add(callback.value(), True)
        self._state[].endpoint = endpoint
        self._state[].active = True
        _servers.get()[].append(self)
        return self


def _initial_servers() -> List[Server]:
    return List[Server]()


comptime _servers = GlobalCell["tsonic.node.net.servers", _initial_servers]()


def _prune_servers():
    var retained = List[Server]()
    for server in _servers.get()[]:
        if server._state[].active or server._state[].closing:
            retained.append(server)
    _servers.get()[] = retained^


def has_active_servers() -> Bool:
    for server in _servers.get()[]:
        if server._state[].referenced and (
            server._state[].active or server._state[].closing
        ):
            return True
    return False


def poll_servers() raises -> Bool:
    var snapshot = _servers.get()[].copy()
    var worked = False
    for server in snapshot:
        if server._state[].active:
            var status = server._state[].endpoint.value().progress()
            if status < 0:
                var retained_server = server
                _ = retained_server.close()
                var error = network_error(status)
                if not server._state[].errors.has_listeners():
                    raise error^
                _ = server._state[].errors.emit((error_new(String(error)),))
                worked = True
            elif status == 1:
                if not server._state[].listening:
                    server._state[].listening = True
                    _ = server._state[].listeners.emit(())
                    worked = True
                for _ in range(16):
                    if not server._state[].active:
                        break
                    var endpoint = server._state[].endpoint.value().accept()
                    if not endpoint:
                        break
                    ref options = server._state[].options
                    var socket = Socket(
                        endpoint.value(),
                        True,
                        options.allow_half_open.value() if options.allow_half_open else False,
                    )
                    if (
                        Bool(options.pause_on_connect)
                        and options.pause_on_connect.value()
                    ):
                        _ = socket.pause()
                    server._state[].connections.append(socket)
                    _ = server._state[].callbacks.emit((socket,))
                    worked = True
        var connections = List[Socket]()
        for socket in server._state[].connections:
            if not socket.destroyed():
                connections.append(socket)
        server._state[].connections = connections^
        if server._state[].closing and len(server._state[].connections) == 0:
            server._state[].closing = False
            server._state[].endpoint = None
            _ = server._state[].closes.emit(())
            worked = True
    _prune_servers()
    return worked
