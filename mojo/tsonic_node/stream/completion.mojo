from tsonic_runtime import GlobalCell, RaisingCallable, TsError
from ..internal.callback_queue import CallbackQueue, CallbackReservation


def _initial_completions() -> CallbackQueue:
    return CallbackQueue(1 << 20)


comptime stream_completions = GlobalCell["tsonic.node.stream.completions", _initial_completions]()

comptime WriteCallback = RaisingCallable[Tuple[Optional[TsError]], NoneType]


struct StreamCompletion(ImplicitlyCopyable):
    var callback: WriteCallback
    var reservation: CallbackReservation

    def __init__(out self, callback: WriteCallback) raises:
        self.callback = callback
        self.reservation = stream_completions.get()[].reserve()

    def complete(self, error: Optional[TsError] = None) raises:
        self.reservation.defer(self.callback, (error.copy(),))


def has_pending_streams() -> Bool:
    return stream_completions.get()[].has_pending()


def poll_streams() raises -> Bool:
    return stream_completions.get()[].poll()
