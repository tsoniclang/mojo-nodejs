from tsonic_runtime import GlobalCell
from ..internal.callback_queue import CallbackQueue, Notification


def _initial_pending() -> CallbackQueue:
    return CallbackQueue(1 << 20)


comptime pending_zlib = GlobalCell["tsonic.node.zlib.pending", _initial_pending]()


def has_pending_zlib() -> Bool:
    return pending_zlib.get()[].has_pending()


def poll_zlib() raises -> Bool:
    return pending_zlib.get()[].poll()


def defer_notification(callback: Notification) raises:
    pending_zlib.get()[].push(callback)
