from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsValue, json_parse, js_value_from_array_values, js_value_from_byte_view
from tsonic_js.value.builder import _JsValueBuilder
from tsonic_node.assertions import deep_strict_equal, deep_strict_equal_with_message
from tsonic_node.assertions.deep import deep_value_equal
from tsonic_node.buffer import Buffer, buffer_to_js_value


def parsed(source: String) raises -> JsValue:
    return json_parse(JsString(source))


def sparse(present: Bool) raises -> JsValue:
    var builder = _JsValueBuilder()
    var children = List[Int]()
    children.append(builder.append_undefined() if present else -1)
    return builder.value(builder.append_array(children^))


def cycle(value: Float64, extra_link: Bool = False) raises -> JsValue:
    var builder = _JsValueBuilder()
    var root = builder.append_array(List[Int]())
    var child = builder.append_array(List[Int]()) if extra_link else root
    var children = List[Int]()
    children.append(builder.append_number(value))
    children.append(child)
    builder.set_aggregate_children(root, children^)
    if extra_link:
        var inner = List[Int]()
        inner.append(builder.append_number(value))
        inner.append(root)
        builder.set_aggregate_children(child, inner^)
    return builder.value(root)


def deeply_nested(depth: Int) raises -> JsValue:
    var builder = _JsValueBuilder()
    var current = builder.append_number(7)
    for _ in range(depth):
        var children = List[Int]()
        children.append(current)
        current = builder.append_array(children^)
    return builder.value(current)


def main() raises:
    deep_strict_equal(parsed('{"name":"item","values":[1,2]}'), parsed('{"values":[1,2],"name":"item"}'))
    assert_false(deep_value_equal(parsed('{"left":1}'), parsed('{"right":1}')))
    assert_false(deep_value_equal(parsed('{"value":{"inner":1}}'), parsed('{"value":{"inner":2}}')))
    assert_false(deep_value_equal(parsed('1'), parsed('"1"')))
    assert_false(deep_value_equal(parsed('null'), JsValue()))
    deep_strict_equal(JsValue(Float64(FloatLiteral.nan)), JsValue(Float64(FloatLiteral.nan)))
    assert_false(deep_value_equal(JsValue(Float64(-0.0)), JsValue(Float64(0.0))))
    deep_strict_equal(sparse(False), sparse(False))
    assert_false(deep_value_equal(sparse(False), sparse(True)))
    assert_false(deep_value_equal(sparse(False), parsed('[]')))
    deep_strict_equal(cycle(1), cycle(1))
    assert_false(deep_value_equal(cycle(1), cycle(2)))
    assert_false(deep_value_equal(cycle(1), cycle(1, True)))
    var child = parsed('{"value":1}')
    var shared = List[JsValue]()
    shared.append(child)
    shared.append(child)
    deep_strict_equal(js_value_from_array_values(shared^), parsed('[{"value":1},{"value":1}]'))
    deep_strict_equal(deeply_nested(4096), deeply_nested(4096))
    var bytes = Buffer.from_string("xabcx")
    var view = bytes.subarray(1, 4)
    var expected = Buffer.from_string("abc")
    deep_strict_equal(buffer_to_js_value(view), buffer_to_js_value(expected))
    bytes.set(1, UInt8(100))
    assert_false(deep_value_equal(buffer_to_js_value(view), buffer_to_js_value(expected)))
    assert_false(deep_value_equal(buffer_to_js_value(view), js_value_from_byte_view(buffer_to_js_value(view).byte_view())))
    var rejected = False
    try:
        deep_strict_equal_with_message(parsed('[1]'), parsed('[2]'), "nested mismatch")
    except error:
        rejected = True
        assert_equal(String(error), "nested mismatch")
    assert_true(rejected)
