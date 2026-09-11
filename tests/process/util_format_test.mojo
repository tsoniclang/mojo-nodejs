from std.collections import List
from std.testing import assert_equal, assert_true
from tsonic_js import JsString, JsValue, json_parse
from tsonic_js.string import string_from_char_code
from tsonic_js.value import js_value_from_bigint
from tsonic_js.value.builder import _JsValueBuilder
from tsonic_node.util_format import format


def main() raises:
    assert_equal(format(List[JsValue]()), "")
    assert_equal(format(List[JsValue](JsValue(JsString("%% %s")))), "%% %s")
    assert_equal(
        format(
            List[JsValue](
                JsValue(JsString("%s:%d")),
                JsValue(JsString("port")),
                JsValue(80.0),
            )
        ),
        "port:80",
    )
    assert_equal(
        format(
            List[JsValue](JsValue(JsString("%s:%s")), JsValue(JsString("x")))
        ),
        "x:%s",
    )
    assert_equal(
        format(
            List[JsValue](
                JsValue(JsString("%% %c%s %q")),
                JsValue(JsString("color:red")),
                JsValue(JsString("😀")),
                JsValue(True),
            )
        ),
        "% 😀 %q true",
    )
    assert_equal(
        format(
            List[JsValue](
                JsValue(JsString("%d %d %d %d")),
                JsValue(JsString("0x20")),
                JsValue(JsString("2junk")),
                JsValue(JsString("\u00a0")),
                JsValue(-0.0),
            )
        ),
        "32 NaN 0 -0",
    )
    assert_equal(
        format(
            List[JsValue](
                JsValue(JsString("%i %f %f %f")),
                JsValue(JsString("12.9tail")),
                JsValue(JsString("1e+tail")),
                JsValue(JsString("-Infinitytail")),
                JsValue(JsString("1.2e2tail")),
            )
        ),
        "12 1 -Infinity 120",
    )
    var integer = js_value_from_bigint(Int64(9007199254740993))
    assert_equal(
        format(
            List[JsValue](
                JsValue(JsString("%s %d %i %j")),
                integer,
                integer,
                integer,
                JsValue(),
            )
        ),
        "9007199254740993n 9007199254740993n 9007199254740993n undefined",
    )
    var object = json_parse(JsString('{"array":[1,2]}'))
    assert_equal(
        format(
            List[JsValue](JsValue(JsString("%s %O %o")), object, object, object)
        ),
        (
            "{ array: [Array] } { array: [ 1, 2 ] } { array: [ 1, 2, [length]:"
            " 2 ] }"
        ),
    )
    var builder = _JsValueBuilder()
    var root = builder.append_array(List[Int]())
    builder.set_aggregate_children(root, List[Int](root))
    assert_equal(
        format(List[JsValue](JsValue(JsString("%j")), builder.value(root))),
        "[Circular]",
    )
    var rejected = False
    try:
        _ = format(List[JsValue](JsValue(JsString("%j")), integer))
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        _ = format(
            List[JsValue](
                JsValue(JsString("%s")),
                JsValue(string_from_char_code(List[Float64](55296.0))),
            )
        )
    except:
        rejected = True
    assert_true(rejected)
