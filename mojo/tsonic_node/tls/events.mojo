from tsonic_runtime import TsError
from ..buffer import Buffer
from ..internal.typed_listeners import TypedListeners


struct SocketEvents(ImplicitlyCopyable):
    var data: TypedListeners[Tuple[Buffer]]
    var errors: TypedListeners[Tuple[TsError]]
    var closes: TypedListeners[Tuple[Bool]]
    var secure: TypedListeners[Tuple[]]
    var ends: TypedListeners[Tuple[]]
    var finishes: TypedListeners[Tuple[]]
    var drains: TypedListeners[Tuple[]]
    var timeouts: TypedListeners[Tuple[]]
    var readable: TypedListeners[Tuple[]]

    def __init__(out self):
        self.data = TypedListeners[Tuple[Buffer]]()
        self.errors = TypedListeners[Tuple[TsError]]()
        self.closes = TypedListeners[Tuple[Bool]]()
        self.secure = TypedListeners[Tuple[]]()
        self.ends = TypedListeners[Tuple[]]()
        self.finishes = TypedListeners[Tuple[]]()
        self.drains = TypedListeners[Tuple[]]()
        self.timeouts = TypedListeners[Tuple[]]()
        self.readable = TypedListeners[Tuple[]]()

    def empty(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event == "secureConnect":
            return self.secure
        if event == "end":
            return self.ends
        if event == "finish":
            return self.finishes
        if event == "drain":
            return self.drains
        if event == "timeout":
            return self.timeouts
        if event == "readable":
            return self.readable
        raise Error("Unsupported TLS socket event: " + event)


def require_event(event: String, expected: String) raises:
    if event != expected:
        raise Error("TLS event does not match its selected listener: " + event)
