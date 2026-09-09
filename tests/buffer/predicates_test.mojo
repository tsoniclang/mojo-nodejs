from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from std.utils import Variant
from tsonic_runtime import Null, Undefined
from tsonic_js import JsValue
from tsonic_node.buffer import Buffer, buffer_is_buffer


@fieldwise_init
struct BufferShaped(Movable):
    var length: Int


def _generic[Value: Movable](value: Value) -> Bool:
    return buffer_is_buffer(value)


def main() raises:
    var buffer = Buffer.from_string("bytes")
    assert_true(buffer_is_buffer(buffer))
    assert_true(buffer_is_buffer(buffer.subarray(1, 3)))
    assert_true(_generic(buffer))
    assert_false(buffer_is_buffer("bytes"))
    assert_false(buffer_is_buffer(0))
    assert_false(buffer_is_buffer(True))
    assert_false(buffer_is_buffer(Null()))
    assert_false(buffer_is_buffer(Undefined()))
    var bytes = List[UInt8]()
    bytes.append(1)
    bytes.append(2)
    assert_false(buffer_is_buffer(bytes))
    assert_false(buffer_is_buffer(BufferShaped(5)))
    assert_false(buffer_is_buffer(JsValue()))
    assert_false(_generic("bytes"))
    var alternatives = Variant[Buffer, String](buffer)
    assert_true(buffer_is_buffer(alternatives))
    alternatives = Variant[Buffer, String](String("bytes"))
    assert_false(buffer_is_buffer(alternatives))
    var optional = Optional[Buffer](buffer)
    assert_true(buffer_is_buffer(optional))
    optional = None
    assert_false(buffer_is_buffer(optional))
    var nested = Variant[Optional[Buffer], String](Optional[Buffer](buffer))
    assert_true(buffer_is_buffer(nested))
    nested = Variant[Optional[Buffer], String](Optional[Buffer]())
    assert_false(buffer_is_buffer(nested))
    assert_equal(buffer.to_string(), "bytes")
