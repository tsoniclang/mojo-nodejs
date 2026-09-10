from std.collections import List
from std.testing import assert_equal
from tsonic_js import JsString, JsValue, json_parse
from tsonic_js.value.builder import _JsValueBuilder
from tsonic_node.buffer import Buffer, buffer_to_js_value
from tsonic_node.util import inspect


def main() raises:
    assert_equal(inspect(JsValue()), "undefined")
    assert_equal(inspect(JsValue(-0.0)), "-0")
    assert_equal(inspect(JsValue(Float64(FloatLiteral.nan))), "NaN")
    assert_equal(inspect(JsValue(JsString("line\nnext"))), "'line\\nnext'")
    assert_equal(
        inspect(json_parse(JsString('{"count":2,"values":[1,true,null]}'))),
        "{ count: 2, values: [ 1, true, null ] }",
    )
    var bytes = Buffer.from_string("ab")
    var saved = buffer_to_js_value(bytes)
    bytes.set(1, 99)
    assert_equal(inspect(saved), "<Buffer 61 63>")
    var builder = _JsValueBuilder()
    var root = builder.append_array(List[Int]())
    var children = List[Int](capacity=3)
    children.append(-1)
    children.append(builder.append_undefined())
    children.append(root)
    builder.set_aggregate_children(root, children^)
    assert_equal(
        inspect(builder.value(root)),
        "[ <1 empty item>, undefined, [Circular] ]",
    )
