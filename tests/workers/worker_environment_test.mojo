from std.collections import List
from std.testing import assert_false, assert_true
from tsonic_js import (
    JsString,
    JsSymbol,
    JsValue,
    js_value_from_array_values,
    js_value_from_object_entries,
)
from tsonic_js.value import JsValueWeakIdentity
from tsonic_node.worker_threads import (
    get_environment_data,
    set_environment_data,
    is_marked_as_untransferable,
    mark_as_untransferable,
)


def expired_mark() raises -> JsValueWeakIdentity:
    var entries = List[JsValue](capacity=1)
    entries.append(JsValue(1.0))
    var value = js_value_from_array_values(entries^)
    mark_as_untransferable(value)
    assert_true(is_marked_as_untransferable(value))
    return JsValueWeakIdentity(value)


def main() raises:
    var key = js_value_from_object_entries(List[JsString](), List[JsValue]())
    var other = js_value_from_object_entries(List[JsString](), List[JsValue]())
    var entries = List[JsValue](capacity=1)
    entries.append(JsValue(42.0))
    var value = js_value_from_array_values(entries^)
    set_environment_data(key, value)
    assert_true(get_environment_data(key).same_identity(value))
    assert_true(get_environment_data(other).is_undefined())
    set_environment_data(key)
    assert_true(get_environment_data(key).is_undefined())

    set_environment_data(JsValue(-0.0), value)
    assert_true(get_environment_data(JsValue(0.0)).same_identity(value))
    set_environment_data(JsValue(0.0), JsValue.undefined())
    assert_true(get_environment_data(JsValue(-0.0)).is_undefined())
    set_environment_data(JsValue(Float64(FloatLiteral.nan)), value)
    assert_true(
        get_environment_data(JsValue(Float64(FloatLiteral.nan))).same_identity(
            value
        )
    )
    set_environment_data(JsValue(Float64(FloatLiteral.nan)))

    var symbol = JsValue(JsSymbol(JsString("key")))
    set_environment_data(symbol, symbol)
    assert_true(get_environment_data(symbol).same_identity(symbol))
    assert_true(
        get_environment_data(JsValue(JsSymbol(JsString("key")))).is_undefined()
    )
    set_environment_data(symbol)

    var released = expired_mark()
    assert_false(released.is_alive())
    assert_false(is_marked_as_untransferable(other))
    mark_as_untransferable(other)
    mark_as_untransferable(other)
    assert_true(is_marked_as_untransferable(other))
