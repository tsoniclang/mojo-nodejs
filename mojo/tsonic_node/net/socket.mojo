from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable, TsError
from ..buffer import Buffer
from ..internal.network_endpoint import AddressInfo, NetworkEndpoint
from ..internal.typed_listeners import TypedListeners
from .state import SocketState, activity, destroy, unsettled
from .transport import end, enqueue, read
from .progress import progress
from .options import ConnectionOptions, timeout_duration


struct Socket(ImplicitlyCopyable):
    var _state: ArcPointer[SocketState]

    def __init__(out self):
        self._state = ArcPointer(SocketState(NetworkEndpoint(), False, False))
        self._state[].started = False

    def __init__(
        out self,
        endpoint: NetworkEndpoint,
        connected: Bool = False,
        allow_half_open: Bool = False,
    ) raises:
        self._state = ArcPointer(
            SocketState(endpoint, connected, allow_half_open)
        )
        if len(_sockets.get()[]) >= 1048576:
            _prune_sockets()
        if len(_sockets.get()[]) >= 1048576:
            raise Error("Network sockets exceed the finite runtime limit")
        _sockets.get()[].append(self)

    def connect_port(mut self, port: Float64) raises -> Self:
        return self.connect_options(ConnectionOptions(port))

    def connect_port_host(mut self, port: Float64, host: String) raises -> Self:
        return self.connect_options(ConnectionOptions(port, host))

    def connect_port_callback(
        mut self, port: Float64, callback: RaisingCallable[Tuple[], NoneType]
    ) raises -> Self:
        return self.connect_options_callback(ConnectionOptions(port), callback)

    def connect_port_host_callback(
        mut self,
        port: Float64,
        host: String,
        callback: RaisingCallable[Tuple[], NoneType],
    ) raises -> Self:
        return self.connect_options_callback(
            ConnectionOptions(port, host), callback
        )

    def connect_options_callback(
        mut self,
        options: ConnectionOptions,
        callback: RaisingCallable[Tuple[], NoneType],
    ) raises -> Self:
        _ = self.connect_options(options)
        return self.once_empty("connect", callback)

    def connect_options(mut self, options: ConnectionOptions) raises -> Self:
        if self._state[].started and (
            not self._state[].destroyed
            or self._state[].close_pending
            or self._state[].error
        ):
            raise Error(
                "Socket connection is active or awaiting close completion"
            )
        var timeout = timeout_duration(
            options.timeout.value()
        ) if options.timeout else self._state[].timeout
        _prune_sockets()
        if len(_sockets.get()[]) >= 1048576:
            raise Error("Network sockets exceed the finite runtime limit")
        var endpoint = NetworkEndpoint(
            options.host.value() if options.host else "localhost",
            options.port,
            False,
        )
        if self._state[].destroyed:
            var replacement = SocketState(
                endpoint, False, self._state[].allow_half_open
            )
            replacement.referenced = self._state[].referenced
            replacement.no_delay = self._state[].no_delay
            replacement.data = self._state[].data
            replacement.errors = self._state[].errors
            replacement.connects = self._state[].connects
            replacement.ends = self._state[].ends
            replacement.finishes = self._state[].finishes
            replacement.drains = self._state[].drains
            replacement.timeouts = self._state[].timeouts
            replacement.readable = self._state[].readable
            replacement.closes = self._state[].closes
            self._state[] = replacement^
        else:
            self._state[].endpoint = endpoint
        self._state[].started = True
        self._state[].timeout = timeout
        if options.allow_half_open:
            self._state[].allow_half_open = options.allow_half_open.value()
        if options.no_delay:
            self._state[].no_delay = options.no_delay
        activity(self._state)
        _sockets.get()[].append(self)
        return self

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        return enqueue(self._state, value)

    def write_string(mut self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def read(mut self) -> Optional[Buffer]:
        return read(self._state)

    def end(mut self) raises -> Self:
        end(self._state)
        return self

    def end_buffer(mut self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(mut self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def destroy(mut self) raises -> Self:
        if not self._state[].started and not self._state[].destroyed:
            _prune_sockets()
            if len(_sockets.get()[]) >= 1048576:
                raise Error("Network sockets exceed the finite runtime limit")
            self._state[].started = True
            _sockets.get()[].append(self)
        destroy(self._state)
        return self

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
        self._state[].flowing = True
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def set_no_delay(mut self, value: Bool = True) raises -> Self:
        self._state[].no_delay = value
        if self._state[].connected and not self._state[].destroyed:
            self._state[].endpoint.no_delay(value)
        return self

    def set_timeout(mut self, timeout: Float64) raises -> Self:
        if self._state[].destroyed:
            return self
        self._state[].timeout = timeout_duration(timeout)
        activity(self._state)
        return self

    def set_timeout_callback(
        mut self, timeout: Float64, callback: RaisingCallable[Tuple[], NoneType]
    ) raises -> Self:
        if self._state[].destroyed:
            return self
        _ = self.set_timeout(timeout)
        if timeout == 0:
            self._state[].timeouts.remove(callback)
        else:
            self._state[].timeouts.add(callback, True)
        return self

    def bytes_read(self) -> Float64:
        return Float64(self._state[].bytes_read)

    def bytes_written(self) -> Float64:
        return Float64(self._state[].bytes_written)

    def destroyed(self) -> Bool:
        return self._state[].destroyed

    def pending(self) -> Bool:
        return not self._state[].connected or self._state[].destroyed

    def connecting(self) -> Bool:
        return (
            self._state[].started
            and not self._state[].connected
            and not self._state[].destroyed
        )

    def remote_address(self) raises -> Optional[String]:
        if not self._state[].connected or self._state[].destroyed:
            return None
        var address = self._state[].endpoint.address(True)
        return address.value().address if address else Optional[String]()

    def remote_port(self) raises -> Optional[Float64]:
        if not self._state[].connected or self._state[].destroyed:
            return None
        var address = self._state[].endpoint.address(True)
        return address.value().port if address else Optional[Float64]()

    def address(self) raises -> Optional[AddressInfo]:
        return self._state[].endpoint.address()

    def on_data(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Buffer], NoneType],
    ) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.add(callback)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def once_data(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Buffer], NoneType],
    ) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.add(callback, True)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def off_data(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Buffer], NoneType],
    ) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.remove(callback)
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

    def on_close(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Bool], NoneType],
    ) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.add(callback)
        return self

    def once_close(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Bool], NoneType],
    ) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.add(callback, True)
        return self

    def off_close(
        mut self,
        event: String,
        callback: RaisingCallable[Tuple[Bool], NoneType],
    ) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.remove(callback)
        return self

    def on_empty(
        mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]
    ) raises -> Self:
        self._empty_event(event).add(callback)
        return self

    def once_empty(
        mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]
    ) raises -> Self:
        self._empty_event(event).add(callback, True)
        return self

    def off_empty(
        mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]
    ) raises -> Self:
        self._empty_event(event).remove(callback)
        return self

    def _empty_event(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event == "connect":
            return self._state[].connects
        if event == "end":
            return self._state[].ends
        if event == "finish":
            return self._state[].finishes
        if event == "drain":
            return self._state[].drains
        if event == "timeout":
            return self._state[].timeouts
        if event == "readable":
            return self._state[].readable
        raise Error("Unsupported socket event: " + event)

    def _require_event(self, event: String, expected: String) raises:
        if event != expected:
            raise Error(
                "Socket event does not match its selected listener: " + event
            )


def _initial_sockets() -> List[Socket]:
    return List[Socket]()


comptime _sockets = GlobalCell["tsonic.node.net.sockets", _initial_sockets]()


def _prune_sockets():
    var retained = List[Socket]()
    for socket in _sockets.get()[]:
        if unsettled(socket._state):
            retained.append(socket)
    _sockets.get()[] = retained^


def has_active_sockets() -> Bool:
    for socket in _sockets.get()[]:
        if socket._state[].close_pending or socket._state[].error:
            return True
        if (
            socket._state[].started
            and not socket.destroyed()
            and socket._state[].referenced
        ):
            return True
    return False


def poll_sockets() raises -> Bool:
    var snapshot = _sockets.get()[].copy()
    var worked = False
    for socket in snapshot:
        worked = progress(socket._state) or worked
    _prune_sockets()
    return worked
