from std.collections import List
from std.memory import ArcPointer
from tsonic_js import JsString, JsValue, js_value_structured_clone
from tsonic_runtime import GlobalCell, RaisingCallable

from .events import EventEmitter


comptime Listener0 = RaisingCallable[Tuple[], NoneType]
comptime Listener1 = RaisingCallable[Tuple[JsValue], NoneType]

comptime _MAX_CHANNELS = 1 << 20
comptime _MAX_PENDING_MESSAGES = 1 << 20
comptime _MESSAGE_EVENT = "message"


struct WorkerOptions(Copyable):
    var name: Optional[String]
    var argv: Optional[List[String]]
    var env: JsValue
    var worker_data: JsValue

    def __init__(
        out self,
        name: Optional[String] = None,
        argv: Optional[List[String]] = None,
        env: JsValue = JsValue.undefined(),
        worker_data: JsValue = JsValue.undefined(),
    ):
        self.name = name
        self.argv = argv
        self.env = env
        self.worker_data = worker_data


struct Worker(ImplicitlyCopyable):
    var _thread_id: Int32

    def __init__(out self, thread_id: Int32):
        self._thread_id = thread_id


@fieldwise_init
struct _PortInbox:
    var messages: List[JsValue]
    var events: EventEmitter
    var started: Bool
    var closed: Bool
    var referenced: Bool


struct MessagePort(ImplicitlyCopyable):
    var _inbox: ArcPointer[_PortInbox]
    var _peer: ArcPointer[_PortInbox]

    def __init__(
        out self,
        inbox: ArcPointer[_PortInbox],
        peer: ArcPointer[_PortInbox],
    ):
        self._inbox = inbox
        self._peer = peer

    def post_message(self, value: JsValue) raises:
        if self._inbox[].closed:
            raise Error("Cannot post from a closed MessagePort")
        if self._peer[].closed:
            return
        if len(self._peer[].messages) >= _MAX_PENDING_MESSAGES:
            raise Error("MessagePort queue exceeds the finite runtime limit")
        self._peer[].messages.append(js_value_structured_clone(value))

    def start(mut self):
        if not self._inbox[].closed:
            self._inbox[].started = True

    def close(mut self):
        self._inbox[].closed = True
        self._inbox[].messages = List[JsValue]()

    def ref_chain(mut self) -> Self:
        self._inbox[].referenced = True
        return self

    def unref_chain(mut self) -> Self:
        self._inbox[].referenced = False
        return self

    def has_ref(self) -> Bool:
        return self._inbox[].referenced

    def on_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        self.start()
        _ = self._inbox[].events.on_callable(event, callback)
        return self

    def on_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        self.start()
        _ = self._inbox[].events.on_callable1(event, callback)
        return self

    def once_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        self.start()
        _ = self._inbox[].events.once_callable(event, callback)
        return self

    def once_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        self.start()
        _ = self._inbox[].events.once_callable1(event, callback)
        return self

    def off_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        _ = self._inbox[].events.off_callable(event, callback)
        return self

    def off_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        _ = self._inbox[].events.off_callable1(event, callback)
        return self


@fieldwise_init
struct MessageChannel(ImplicitlyCopyable):
    var port1: MessagePort
    var port2: MessagePort


@fieldwise_init
struct _EnvironmentEntry(Copyable):
    var key: String
    var value: JsValue


def _initial_ports() -> List[ArcPointer[_PortInbox]]:
    return List[ArcPointer[_PortInbox]]()


def _initial_environment() -> List[_EnvironmentEntry]:
    return List[_EnvironmentEntry]()


def _initial_untransferable() -> List[JsValue]:
    return List[JsValue]()


comptime _ports = GlobalCell[
    "tsonic.node.worker-threads.ports",
    _initial_ports,
]()
comptime _environment = GlobalCell[
    "tsonic.node.worker-threads.environment",
    _initial_environment,
]()
comptime _untransferable = GlobalCell[
    "tsonic.node.worker-threads.untransferable",
    _initial_untransferable,
]()


def message_channel_new() raises -> MessageChannel:
    if len(_ports.get()[]) > _MAX_CHANNELS - 2:
        raise Error("MessageChannel count exceeds the finite runtime limit")
    var first = ArcPointer(
        _PortInbox(List[JsValue](), EventEmitter(), False, False, True)
    )
    var second = ArcPointer(
        _PortInbox(List[JsValue](), EventEmitter(), False, False, True)
    )
    _ports.get()[].append(first)
    _ports.get()[].append(second)
    return MessageChannel(
        MessagePort(first, second),
        MessagePort(second, first),
    )


def receive_message_on_port(port: MessagePort) raises -> JsValue:
    if len(port._inbox[].messages) == 0:
        return JsValue.undefined()
    return _shift_message(port._inbox[].messages)


def get_environment_data(key: String) raises -> JsValue:
    for entry in _environment.get()[]:
        if entry.key == key:
            return js_value_structured_clone(entry.value)
    return JsValue.undefined()


def set_environment_data(key: String, value: JsValue) raises:
    var replacement = js_value_structured_clone(value)
    for index in range(len(_environment.get()[])):
        if _environment.get()[][index].key == key:
            _environment.get()[][index].value = replacement
            return
    if len(_environment.get()[]) >= _MAX_CHANNELS:
        raise Error("Worker environment data exceeds the finite runtime limit")
    _environment.get()[].append(_EnvironmentEntry(key, replacement))


def mark_as_untransferable(value: JsValue) raises:
    _require_reference_value(value)
    for existing in _untransferable.get()[]:
        if existing.same_identity(value):
            return
    if len(_untransferable.get()[]) >= _MAX_CHANNELS:
        raise Error(
            "Untransferable identity set exceeds the finite runtime limit"
        )
    _untransferable.get()[].append(value)


def is_marked_as_untransferable(value: JsValue) raises -> Bool:
    _require_reference_value(value)
    for existing in _untransferable.get()[]:
        if existing.same_identity(value):
            return True
    return False


def is_main_thread() -> Bool:
    return True


def thread_id() -> Float64:
    return 0


def worker_data() -> JsValue:
    return JsValue.undefined()


def parent_port() -> Optional[MessagePort]:
    return None


def poll_worker_threads() raises -> Bool:
    var did_work = False
    var retained = List[ArcPointer[_PortInbox]]()
    for inbox in _ports.get()[]:
        if inbox[].closed:
            continue
        retained.append(inbox)
        if not inbox[].started or len(inbox[].messages) == 0:
            continue
        var value = _shift_message(inbox[].messages)
        _ = inbox[].events.emit_callable1(
            JsValue(JsString(_MESSAGE_EVENT)), value
        )
        did_work = True
    _ports.get()[] = retained^
    return did_work


def has_active_worker_threads() -> Bool:
    for inbox in _ports.get()[]:
        if (
            not inbox[].closed
            and inbox[].started
            and inbox[].referenced
            and len(inbox[].messages) != 0
        ):
            return True
    return False


def _shift_message(mut values: List[JsValue]) -> JsValue:
    var result = values[0]
    var retained = List[JsValue](capacity=len(values) - 1)
    for index in range(1, len(values)):
        retained.append(values[index])
    values = retained^
    return result


def _require_reference_value(value: JsValue) raises:
    if not value.is_array() and not value.is_object():
        raise Error(
            "Only JavaScript object identities can be marked untransferable"
        )
