from tsonic_runtime import GlobalCell
from ..internal.callback_queue import CallbackQueue, CallbackReservation, Notification


def _initial_completions() -> CallbackQueue:
    return CallbackQueue(1 << 20)


comptime stream_completions = GlobalCell["tsonic.node.stream.completions", _initial_completions]()


struct StreamCompletion(ImplicitlyCopyable):
    var callback: Notification
    var reservation: CallbackReservation

    def __init__(out self, callback: Notification) raises:
        self.callback = callback
        self.reservation = stream_completions.get()[].reserve()

    def complete(self) raises:
        self.reservation.commit(self.callback)


def has_pending_streams() -> Bool:
    return stream_completions.get()[].has_pending()


def poll_streams() raises -> Bool:
    return stream_completions.get()[].poll()
