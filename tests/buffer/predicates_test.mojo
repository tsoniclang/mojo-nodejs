from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsValue, json_parse
from tsonic_node.buffer import Buffer, buffer_is_buffer, buffer_to_js_value


def main() raises:
    var buffer = Buffer.from_string("bytes")
    assert_true(buffer_is_buffer(buffer_to_js_value(buffer)))
    assert_true(buffer_is_buffer(buffer_to_js_value(buffer.subarray(1, Float64(3)))))
    assert_false(buffer_is_buffer(JsValue(String("bytes"))))
    assert_false(buffer_is_buffer(JsValue(Float64(0))))
    assert_false(buffer_is_buffer(JsValue(True)))
    assert_false(buffer_is_buffer(json_parse(JsString("null"))))
    assert_false(buffer_is_buffer(JsValue()))
    assert_false(buffer_is_buffer(json_parse(JsString("[1,2]"))))
    assert_false(buffer_is_buffer(json_parse(JsString('{"length":5}'))))
    assert_equal(buffer.to_string(), "bytes")
