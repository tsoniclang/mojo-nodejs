from std.collections import List
from tsonic_runtime import GlobalCell, RaisingCallable


comptime Notification = RaisingCallable[Tuple[], NoneType]
comptime MAX_PENDING = 1 << 20


def _initial_pending() -> List[Notification]:
    return List[Notification]()


comptime _pending = GlobalCell["tsonic.node.zlib.pending", _initial_pending]()


def has_pending_zlib() -> Bool:
    return len(_pending.get()[]) != 0


def poll_zlib() raises -> Bool:
    if len(_pending.get()[]) == 0:
        return False
    var pending = _pending.get()[].copy()
    _pending.get()[] = List[Notification]()
    for index in range(len(pending)):
        try:
            pending[index].call(())
        except error:
            var retained = List[Notification]()
            for next_index in range(index + 1, len(pending)):
                retained.append(pending[next_index])
            for entry in _pending.get()[]:
                retained.append(entry)
            _pending.get()[] = retained^
            raise error
    return True


def defer_notification(callback: Notification) raises:
    if len(_pending.get()[]) >= MAX_PENDING:
        raise Error("Pending compression callbacks exceed the finite runtime limit")
    _pending.get()[].append(callback)



def pending_count() -> Int:
    return len(_pending.get()[])
