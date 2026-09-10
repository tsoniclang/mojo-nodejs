from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable, TsError
from ..buffer import Buffer
from ..internal.network_endpoint import AddressInfo, NetworkEndpoint
from ..internal.typed_listeners import TypedListeners
from .state import SocketState, activity, destroy, unsettled
from .transport import end, enqueue, read
from .progress import progress
from .options import timeout_duration


struct Socket(ImplicitlyCopyable):
    var _state: ArcPointer[SocketState]

    def __init__(out self, endpoint: NetworkEndpoint, connected: Bool = False, allow_half_open: Bool = False) raises:
        self._state = ArcPointer(SocketState(endpoint, connected, allow_half_open))
        if len(_sockets.get()[]) >= 1048576:
            _prune_sockets()
        if len(_sockets.get()[]) >= 1048576:
            raise Error("Network sockets exceed the finite runtime limit")
        _sockets.get()[].append(self)

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

    def destroy(mut self) -> Self:
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

    def set_timeout_callback(mut self, timeout: Float64, callback: RaisingCallable[Tuple[], NoneType]) raises -> Self:
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

    def address(self) raises -> Optional[AddressInfo]:
        return self._state[].endpoint.address()

    def on_data(mut self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.add(callback)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def once_data(mut self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.add(callback, True)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def off_data(mut self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]) raises -> Self:
        self._require_event(event, "data")
        self._state[].data.remove(callback)
        return self

    def on_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.add(callback)
        return self

    def once_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.add(callback, True)
        return self

    def off_error(mut self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]) raises -> Self:
        self._require_event(event, "error")
        self._state[].errors.remove(callback)
        return self

    def on_close(mut self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.add(callback)
        return self

    def once_close(mut self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.add(callback, True)
        return self

    def off_close(mut self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]) raises -> Self:
        self._require_event(event, "close")
        self._state[].closes.remove(callback)
        return self

    def on_empty(mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]) raises -> Self:
        self._empty_event(event).add(callback)
        return self

    def once_empty(mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]) raises -> Self:
        self._empty_event(event).add(callback, True)
        return self

    def off_empty(mut self, event: String, callback: RaisingCallable[Tuple[], NoneType]) raises -> Self:
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
            raise Error("Socket event does not match its selected listener: " + event)


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
        if not socket.destroyed() and socket._state[].referenced:
            return True
    return False


def poll_sockets() raises -> Bool:
    var snapshot = _sockets.get()[].copy()
    var worked = False
    for socket in snapshot:
        worked = progress(socket._state) or worked
    _prune_sockets()
    return worked
