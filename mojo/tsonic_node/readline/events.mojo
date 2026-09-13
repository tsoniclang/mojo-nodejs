from tsonic_runtime import RaisingCallable, TsError
from ..internal.typed_listeners import TypedListeners


comptime LineCallback = RaisingCallable[Tuple[String], NoneType]
comptime ErrorCallback = RaisingCallable[Tuple[TsError], NoneType]


@fieldwise_init
struct InterfaceEvents(ImplicitlyCopyable):
    var lines: TypedListeners[Tuple[String]]
    var errors: TypedListeners[Tuple[TsError]]
    var pause: TypedListeners[Tuple[]]
    var resume: TypedListeners[Tuple[]]
    var close: TypedListeners[Tuple[]]

    def __init__(out self):
        self.lines = TypedListeners[Tuple[String]]()
        self.errors = TypedListeners[Tuple[TsError]]()
        self.pause = TypedListeners[Tuple[]]()
        self.resume = TypedListeners[Tuple[]]()
        self.close = TypedListeners[Tuple[]]()

    def notifications(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event == "pause":
            return self.pause
        if event == "resume":
            return self.resume
        if event == "close":
            return self.close
        raise Error("Unsupported readline notification: ", event)

    def require_line(self, event: String) raises:
        if event != "line":
            raise Error("Unsupported readline line event: ", event)

    def require_error(self, event: String) raises:
        if event != "error":
            raise Error("Unsupported readline error event: ", event)

    def fail(self, error: TsError) raises:
        if not self.errors.emit((error.copy(),)):
            raise error.native_error()
