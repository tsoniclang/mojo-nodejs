from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import Buffer


def main() raises:
    var buffer = Buffer.from_string("hello")
    assert_equal(len(buffer), 5)
    assert_equal(buffer.get(1), UInt8(101))
    assert_equal(buffer.to_string(), "hello")

    var view = buffer.subarray(1, 4)
    assert_equal(view.to_string(), "ell")
    assert_true(buffer.same_storage(view))
    view.set(0, UInt8(65))
    assert_equal(buffer.to_string(), "hAllo")

    var copy = Buffer(buffer.copy_bytes())
    assert_false(buffer.same_storage(copy))
    assert_equal(copy.to_string(), "hAllo")

    var allocated = Buffer.allocate(3, UInt8(7))
    assert_equal(allocated.get(2), UInt8(7))

    var copied = Buffer.allocate(5)
    assert_equal(buffer.copy(copied, 1, 1, 4), 3)
    assert_equal(copied.get(1), UInt8(65))
    assert_true(buffer.slice(1, 3).same_storage(buffer))

    var numbers = Buffer.allocate(8)
    _ = numbers.write_uint16_be(0x1234, 0)
    assert_equal(numbers.read_uint16_be(0), 0x1234)
    _ = numbers.write_int32_le(-2, 0)
    assert_equal(numbers.read_int32_le(0), -2)
    _ = numbers.write_float_be(1.5, 0)
    assert_equal(numbers.read_float_be(0), 1.5)
    _ = numbers.write_double_le(3.25, 0)
    assert_equal(numbers.read_double_le(0), 3.25)

    var swapped = Buffer.allocate(4)
    swapped.set(0, 1)
    swapped.set(1, 2)
    swapped.set(2, 3)
    swapped.set(3, 4)
    _ = swapped.swap16()
    assert_equal(swapped.get(0), 2)
    assert_equal(swapped.get(1), 1)
    _ = swapped.swap32()
    assert_equal(swapped.get(0), 3)
