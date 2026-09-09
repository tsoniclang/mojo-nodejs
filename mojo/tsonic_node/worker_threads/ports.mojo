from std.collections import List
from std.memory import ArcPointer
from tsonic_js import JsString, JsValue, js_value_error
from tsonic_runtime import GlobalCell, RaisingCallable
from ..events import EventEmitter
from .native import WorkerChannel
from .transport import MessagePacket, PortTransport, local_pair


comptime Listener0 = RaisingCallable[Tuple[], NoneType]
comptime Listener1 = RaisingCallable[Tuple[JsValue], NoneType]
comptime INITIALIZE = UInt8(0)
comptime ONLINE = UInt8(1)
comptime MESSAGE = UInt8(2)
comptime FAILURE = UInt8(3)
comptime PORT_CLOSED = UInt8(4)


struct PortState:
    var channel: PortTransport
    var events: EventEmitter
    var started: Bool
    var referenced: Bool
    var closing: Bool
    var closed: Bool
    var close_emitted: Bool
    var worker: Bool
    var exited: Bool
    var exit_code: Optional[Int32]
    var online: Bool
    var peer_closed: Bool
    var terminating: Bool

    def __init__(out self, channel: PortTransport, worker: Bool):
        self.channel = channel
        self.events = EventEmitter()
        self.started = worker
        self.referenced = worker
        self.closing = False
        self.closed = False
        self.close_emitted = False
        self.worker = worker
        self.exited = False
        self.exit_code = None
        self.online = False
        self.peer_closed = False
        self.terminating = False


def _initial_ports() -> List[ArcPointer[PortState]]:
    return List[ArcPointer[PortState]]()


comptime _ports = GlobalCell["tsonic.node.worker-threads.ports", _initial_ports]()


struct MessagePort(ImplicitlyCopyable):
    var _state: ArcPointer[PortState]

    def __init__(out self, state: ArcPointer[PortState]):
        self._state = state

    def post_message(self, value: JsValue) raises:
        if self._state[].closing or self._state[].closed or self._state[].peer_closed:
            return
        self._state[].channel.send_value(value)

    def start(mut self):
        if not self._state[].closed:
            self._state[].started = True

    def close(mut self) raises:
        if self._state[].closing or self._state[].closed:
            return
        self._state[].channel.close_data()
        self._state[].closing = True
        self._state[].closed = True

    def ref_chain(mut self) -> Self:
        self._state[].referenced = True
        return self

    def unref_chain(mut self) -> Self:
        self._state[].referenced = False
        return self

    def has_ref(self) -> Bool:
        return self._state[].referenced and not self._state[].closed

    def _listening(mut self, event: JsValue):
        if event.is_string() and event.string_value() == JsString("message"):
            self.start()
            self._state[].referenced = True

    def on_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        _ = self._state[].events.on_callable(event, callback)
        self._listening(event)
        return self

    def on_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        _ = self._state[].events.on_callable1(event, callback)
        self._listening(event)
        return self

    def once_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        _ = self._state[].events.once_callable(event, callback)
        self._listening(event)
        return self

    def once_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        _ = self._state[].events.once_callable1(event, callback)
        self._listening(event)
        return self

    def off_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        _ = self._state[].events.off_callable(event, callback)
        if self._state[].events.listener_count(JsValue(JsString("message"))) == 0:
            self._state[].referenced = False
        return self

    def off_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        _ = self._state[].events.off_callable1(event, callback)
        if self._state[].events.listener_count(JsValue(JsString("message"))) == 0:
            self._state[].referenced = False
        return self


@fieldwise_init
struct MessageChannel(ImplicitlyCopyable):
    var port1: MessagePort
    var port2: MessagePort


@fieldwise_init
struct MessagePortMessage(ImplicitlyCopyable):
    var message: JsValue


def register_port(channel: WorkerChannel, worker: Bool = False) raises -> MessagePort:
    return _register_transport(PortTransport(channel), worker)


def _register_transport(channel: PortTransport, worker: Bool) raises -> MessagePort:
    if len(_ports.get()[]) >= 1048576:
        raise Error("Message channel inventory exceeds its limit")
    var state = ArcPointer(PortState(channel, worker))
    _ports.get()[].append(state)
    return MessagePort(state)


def message_channel_new() raises -> MessageChannel:
    if len(_ports.get()[]) > 1048574:
        raise Error("Message channel inventory exceeds its limit")
    var pair = local_pair()
    var first = _register_transport(pair[0], False)
    var second = _register_transport(pair[1], False)
    return MessageChannel(first, second)


def receive_message_on_port(port: MessagePort) raises -> Optional[MessagePortMessage]:
    if port._state[].closed:
        return None
    var frame = port._state[].channel.receive()
    if not frame:
        return None
    var packet = frame.take()
    if packet.kind != MESSAGE:
        raise Error("MessagePort received an invalid protocol frame")
    return MessagePortMessage(packet.value)


def _poll_state(state: ArcPointer[PortState]) raises -> Bool:
    var worked = False
    if state[].channel.pending() and state[].closed:
        try:
            state[].channel.progress()
        except error:
            _transport_failure(state, String(error))
    if not state[].closed:
        try:
            state[].channel.progress()
        except error:
            _transport_failure(state, String(error))
            return True
        if state[].closing and not state[].channel.pending():
            state[].channel.close()
            state[].closed = True
        elif state[].started:
            var frame = Optional[MessagePacket]()
            try:
                frame = state[].channel.receive()
            except error:
                _transport_failure(state, String(error))
                return True
            if frame:
                var packet = frame.take()
                worked = True
                if packet.kind == MESSAGE:
                    _ = state[].events.emit_callable1(JsValue(JsString("message")), packet.value)
                elif packet.kind == ONLINE and state[].worker and not state[].online:
                    state[].online = True
                    _ = state[].events.emit_callable(JsValue(JsString("online")))
                elif packet.kind == PORT_CLOSED:
                    state[].peer_closed = True
                    if not state[].worker:
                        state[].closed = True
                elif packet.kind == FAILURE and state[].worker:
                    var value = packet.value
                    if not value.is_string():
                        raise Error("Worker failure frame has no message")
                    var error = js_value_error(value.string_value().to_native_strict())
                    if state[].events.listener_count(JsValue(JsString("error"))) == 0:
                        raise Error(value.string_value().to_native_strict())
                    _ = state[].events.emit_callable1(JsValue(JsString("error")), error)
                else:
                    raise Error("Worker channel received an invalid protocol frame")
        if state[].channel.closed():
            state[].closed = True
    if state[].worker and not state[].exited:
        var code = state[].channel.exit_code()
        if code:
            state[].exit_code = code
        if state[].closed and state[].exit_code:
            state[].exited = True
            worked = True
            try:
                _ = state[].events.emit_callable1(JsValue(JsString("exit")), JsValue(Float64(state[].exit_code.value())))
            finally:
                _ = state[].events.remove_all_listeners()
    elif not state[].worker and state[].closed and not state[].close_emitted:
        state[].close_emitted = True
        worked = True
        _ = state[].events.emit_callable(JsValue(JsString("close")))
    return worked


def _transport_failure(state: ArcPointer[PortState], message: String) raises:
    state[].closed = True
    state[].channel.close()
    if state[].worker:
        state[].channel.terminate()
        if state[].terminating:
            return
    var name = JsValue(JsString("error" if state[].worker else "messageerror"))
    if state[].worker and state[].events.listener_count(name) == 0:
        raise Error(message)
    _ = state[].events.emit_callable1(name, js_value_error(message))


def poll_worker_threads() raises -> Bool:
    var worked = False
    var snapshot = _ports.get()[].copy()
    for state in snapshot:
        worked = _poll_state(state) or worked
    var retained = List[ArcPointer[PortState]]()
    for state in _ports.get()[]:
        if state[].channel.pending() or (state[].worker and not state[].exited) or (not state[].worker and not state[].close_emitted):
            retained.append(state)
    _ports.get()[] = retained^
    return worked


def has_active_worker_threads() -> Bool:
    for state in _ports.get()[]:
        if state[].channel.pending() or (state[].closing and not state[].close_emitted and not state[].worker):
            return True
        if state[].referenced and ((state[].worker and not state[].exited) or (state[].started and not state[].closed)):
            return True
    return False
