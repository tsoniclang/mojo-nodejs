from std.collections import List
from tsonic_js import JsValue, object_is, js_value_from_array_values
from tsonic_runtime import GlobalCell


@fieldwise_init
struct EnvironmentEntry(ImplicitlyCopyable):
    var key: JsValue
    var value: JsValue


def _initial_environment() -> List[EnvironmentEntry]:
    return List[EnvironmentEntry]()


comptime _environment = GlobalCell["tsonic.node.worker-threads.environment", _initial_environment]()


def _key_equal(left: JsValue, right: JsValue) -> Bool:
    if left.is_number() and right.is_number() and left._number_value() == 0 and right._number_value() == 0:
        return True
    return object_is(left, right)


def get_environment_data(key: JsValue) -> JsValue:
    for entry in _environment.get()[]:
        if _key_equal(entry.key, key):
            return entry.value
    return JsValue.undefined()


def set_environment_data(key: JsValue, value: JsValue = JsValue.undefined()) raises:
    for index in range(len(_environment.get()[])):
        if _key_equal(_environment.get()[][index].key, key):
            if value.is_undefined():
                _ = _environment.get()[].pop(index)
            else:
                _environment.get()[][index].value = value
            return
    if value.is_undefined():
        return
    if len(_environment.get()[]) >= 1048576:
        raise Error("Worker environment data exceeds the finite runtime limit")
    _environment.get()[].append(EnvironmentEntry(key, value))


def environment_snapshot() raises -> JsValue:
    var entries = List[JsValue]()
    for entry in _environment.get()[]:
        entries.append(js_value_from_array_values(List[JsValue](entry.key, entry.value)))
    return js_value_from_array_values(entries^)


def restore_environment(snapshot: JsValue) raises:
    if not snapshot.is_array():
        raise Error("Worker environment snapshot is not an entry array")
    var entries = List[EnvironmentEntry]()
    for index in range(snapshot.array_length()):
        var pair = snapshot.array_at(index)
        if not pair.is_array() or pair.array_length() != 2:
            raise Error("Worker environment snapshot contains an invalid entry")
        var key = pair.array_at(0)
        var value = pair.array_at(1)
        if value.is_undefined():
            raise Error("Worker environment snapshot contains a deleted entry")
        for existing in entries:
            if _key_equal(existing.key, key):
                raise Error("Worker environment snapshot contains a duplicate key")
        entries.append(EnvironmentEntry(key, value))
    _environment.get()[] = entries^
