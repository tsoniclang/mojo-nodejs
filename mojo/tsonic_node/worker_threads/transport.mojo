from std.collections import List
from std.memory import ArcPointer
from tsonic_js import JsValue, js_value_structured_clone
from tsonic_js.value import encode_structured_clone, decode_structured_clone
from .native import WorkerChannel


@fieldwise_init
struct MessagePacket(ImplicitlyCopyable):
    var kind: UInt8
    var value: JsValue


struct LocalInbox:
    var messages: List[JsValue]
    var head: Int
    var closed: Bool

    def __init__(out self):
        self.messages = List[JsValue]()
        self.head = 0
        self.closed = False

    def empty(self) -> Bool:
        return self.head == len(self.messages)

    def receive(mut self) -> Optional[MessagePacket]:
        if self.empty():
            return None
        var result = MessagePacket(UInt8(2), self.messages[self.head])
        self.messages[self.head] = JsValue.undefined()
        self.head += 1
        if self.head >= 1024 and self.head * 2 >= len(self.messages):
            var retained = List[JsValue](
                capacity=len(self.messages) - self.head
            )
            for index in range(self.head, len(self.messages)):
                retained.append(self.messages[index])
            self.messages = retained^
            self.head = 0
        return result


@fieldwise_init
struct LocalTransport(ImplicitlyCopyable):
    var inbox: ArcPointer[LocalInbox]
    var peer: ArcPointer[LocalInbox]


struct PortTransport(ImplicitlyCopyable):
    var _local: Optional[LocalTransport]
    var _remote: Optional[WorkerChannel]

    def __init__(out self, local: LocalTransport):
        self._local = local
        self._remote = None

    def __init__(out self, remote: WorkerChannel):
        self._local = None
        self._remote = remote

    def close(self):
        if self._local:
            self._local.value().inbox[].closed = True
            self._local.value().inbox[].messages = List[JsValue]()
            self._local.value().inbox[].head = 0
        else:
            self._remote.value().close()

    def closed(self) -> Bool:
        if self._local:
            var local = self._local.value()
            return local.inbox[].closed or (
                local.peer[].closed and local.inbox[].empty()
            )
        return self._remote.value().closed()

    def close_data(self) raises:
        if self._local:
            self.close()
        elif not self._remote.value().closed():
            self._remote.value().send(UInt8(4), List[UInt8]())

    def progress(self) raises:
        if self._remote:
            self._remote.value().progress()

    def pending(self) -> Bool:
        return self._remote.value().pending() if self._remote else False

    def send_value(self, value: JsValue) raises:
        if self._local:
            var local = self._local.value()
            if local.inbox[].closed or local.peer[].closed:
                return
            if len(local.peer[].messages) - local.peer[].head >= 1048576:
                raise Error("Message channel queue exceeds its limit")
            local.peer[].messages.append(js_value_structured_clone(value))
        else:
            var bytes = encode_structured_clone(value)
            self._remote.value().send(UInt8(2), bytes)

    def receive(self) raises -> Optional[MessagePacket]:
        if self._local:
            return self._local.value().inbox[].receive()
        var frame = self._remote.value().receive()
        if not frame:
            return None
        var packet = frame.take()
        if packet.kind == 1 or packet.kind == 4:
            if len(packet.bytes) != 0:
                raise Error(
                    "Worker control frame contains an unexpected payload"
                )
            return MessagePacket(packet.kind, JsValue.undefined())
        if packet.kind != 2 and packet.kind != 3:
            raise Error("Worker channel received an invalid frame kind")
        var kind = packet.kind
        var bytes = List[UInt8]()
        swap(bytes, packet.bytes)
        return MessagePacket(kind, decode_structured_clone(bytes^))

    def exit_code(self) raises -> Optional[Int32]:
        return self._remote.value().exit_code() if self._remote else Optional[
            Int32
        ]()

    def id(self) -> Float64:
        return self._remote.value().id() if self._remote else 0

    def terminate(self) raises:
        if self._remote:
            self._remote.value().terminate()

    def flush(self) raises:
        if self._remote:
            self._remote.value().flush()

    def send_failure(self, value: JsValue) raises:
        if not self._remote:
            raise Error("Worker failure requires a process channel")
        var bytes = encode_structured_clone(value)
        self._remote.value().send(UInt8(3), bytes)


def local_pair() -> Tuple[PortTransport, PortTransport]:
    var first = ArcPointer(LocalInbox())
    var second = ArcPointer(LocalInbox())
    return (
        PortTransport(LocalTransport(first, second)),
        PortTransport(LocalTransport(second, first)),
    )
