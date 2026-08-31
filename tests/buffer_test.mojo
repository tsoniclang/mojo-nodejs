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
