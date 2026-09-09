from std.collections import List
from tsonic_js import JsValue, object_is
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
