from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import (
    JsString,
    JsValue,
    json_parse,
    json_stringify,
    js_value_from_array_values,
    js_value_structured_clone,
    object_keys,
    js_value_to_string,
)
from tsonic_js.value import encode_structured_clone, decode_structured_clone
from tsonic_js.inspection import inspect_value
from tsonic_node.buffer import (
    Buffer,
    buffer_to_js_value,
    buffer_from_js_value,
    buffer_is_buffer,
)


def main() raises:
    var source = Buffer.from_string("abc")
    var saved = buffer_to_js_value(source)
    var second = buffer_to_js_value(source)
    var slice = buffer_to_js_value(source.subarray(1))
    assert_true(buffer_is_buffer(saved))
    assert_true(saved.same_identity(second))
    assert_false(saved.same_identity(slice))
    source.set(1, 90)
    assert_equal(saved.object_value(1).number_value(), 90)
    assert_equal(slice.object_value(0).number_value(), 90)
    assert_equal(js_value_to_string(saved).to_native_strict(), "aZc")
    assert_equal(inspect_value(saved), "<Buffer 61 5a 63>")
    assert_equal(len(object_keys(saved)), 3)
    assert_equal(
        json_stringify(saved).value().to_native_strict(),
        '{"type":"Buffer","data":[97,90,99]}',
    )
    var fake = json_parse(
        JsString(
            '{"type":"Buffer","data":[97,90,99],"brand":"node:buffer::Buffer"}'
        )
    )
    assert_false(buffer_is_buffer(fake))
    var values = List[JsValue]()
    values.append(saved)
    values.append(second)
    values.append(slice)
    var original = js_value_from_array_values(values^)
    var clone = js_value_structured_clone(original)
    assert_false(buffer_is_buffer(clone.array_at(0)))
    assert_true(clone.array_at(0).is_byte_view())
    assert_true(clone.array_at(0).same_identity(clone.array_at(1)))
    assert_false(clone.array_at(0).same_identity(saved))
    assert_equal(
        json_stringify(clone.array_at(0)).value().to_native_strict(),
        '{"0":97,"1":90,"2":99}',
    )
    clone.array_at(0).byte_view().set(1, 81)
    assert_equal(clone.array_at(2).byte_view().get(0), 81)
    assert_equal(source.get(1), 90)
    var transported = decode_structured_clone(encode_structured_clone(original))
    assert_false(buffer_is_buffer(transported.array_at(0)))
    assert_true(transported.array_at(0).same_identity(transported.array_at(1)))
    transported.array_at(2).byte_view().set(0, 88)
    assert_equal(transported.array_at(0).byte_view().get(1), 88)
    assert_equal(source.get(1), 90)
    source.set(0, 255)
    assert_equal(js_value_to_string(saved).to_native_strict(), "�Zc")
    assert_equal(buffer_is_buffer(saved), True)
    var recovered = buffer_from_js_value(saved)
    assert_true(recovered == source)
    recovered.set(1, 84)
    assert_equal(source.get(1), 84)
    var recovered_slice = buffer_from_js_value(slice)
    assert_false(recovered_slice == source)
    assert_equal(len(recovered_slice), 2)
    recovered_slice.set(0, 80)
    assert_equal(source.get(1), 80)
    assert_true(buffer_to_js_value(recovered_slice).same_identity(slice))
    var invalid = List[JsValue]()
    invalid.append(fake)
    invalid.append(clone.array_at(0))
    invalid.append(transported.array_at(0))
    invalid.append(JsValue(Float64(3)))
    for value in invalid:
        var rejected = False
        try:
            _ = buffer_from_js_value(value)
        except:
            rejected = True
        assert_true(rejected)
