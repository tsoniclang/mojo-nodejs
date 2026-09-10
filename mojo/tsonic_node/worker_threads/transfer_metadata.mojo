from std.collections import List
from tsonic_js import JsValue
from tsonic_js.value import JsValueWeakIdentity
from tsonic_runtime import GlobalCell


def _initial_untransferable() -> List[JsValueWeakIdentity]:
    return List[JsValueWeakIdentity]()


comptime _untransferable = GlobalCell["tsonic.node.worker-threads.untransferable", _initial_untransferable]()


def _prune_and_find(value: JsValue) -> Bool:
    var found = False
    var retained = 0
    ref entries = _untransferable.get()[]
    for index in range(len(entries)):
        if not entries[index].is_alive():
            continue
        found = entries[index].matches(value) or found
        if retained != index:
            entries[retained] = entries[index]
        retained += 1
    entries.shrink(retained)
    return found


def mark_as_untransferable(value: JsValue) raises:
    if not value.is_array() and not value.is_object():
        return
    if _prune_and_find(value):
        return
    if len(_untransferable.get()[]) >= 1048576:
        raise Error("Untransferable identity set exceeds the finite runtime limit")
    _untransferable.get()[].append(JsValueWeakIdentity(value))


def is_marked_as_untransferable(value: JsValue) -> Bool:
    return _prune_and_find(value)
