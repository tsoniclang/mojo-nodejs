from std.collections import List
from std.math import FloatLiteral
from std.testing import assert_equal, assert_true
from tsonic_node.buffer import (
    Buffer,
    buffer_alloc,
    buffer_alloc_unsafe,
    buffer_alloc_unsafe_slow,
    buffer_concat,
    buffer_from_buffer,
    buffer_from_numbers,
    buffer_from_string,
    buffer_pool_size,
    set_buffer_pool_size,
)


def pool_allocation() raises:
    set_buffer_pool_size(64)
    assert_equal(buffer_pool_size(), 64)
    var first = buffer_alloc_unsafe(3)
    var second = buffer_alloc_unsafe(5)
    var text = buffer_from_string("hi")
    var codes = List[Float64](capacity=2)
    codes.append(65)
    codes.append(66)
    var numbers = buffer_from_numbers(codes)
    _ = first.fill_number(67)
    var copied = buffer_from_buffer(first)
    var pieces = List[Buffer](capacity=2)
    pieces.append(text)
    pieces.append(numbers)
    var joined = buffer_concat(pieces, 6)
    var last = buffer_alloc_unsafe(15)
    var rolled = buffer_alloc_unsafe(1)
    assert_equal(first._offset, 0)
    assert_equal(second._offset, 8)
    assert_equal(text._offset, 16)
    assert_equal(numbers._offset, 24)
    assert_equal(copied._offset, 32)
    assert_equal(joined._offset, 40)
    assert_equal(last._offset, 48)
    assert_equal(rolled._offset, 0)
    assert_true(first.same_storage(last))
    assert_true(not first.same_storage(rolled))
    assert_equal(copied.to_string(), "CCC")
    assert_equal(joined.to_string("hex"), "686941420000")

    var retained_alias = first
    var view = first.subarray()
    assert_true(first == retained_alias)
    assert_true(first != view)
    assert_true(first != copied)
    assert_true(first.same_storage(view))
    assert_true(first.same_storage(copied))
    assert_true(first.equals(copied))
    view.set(0, 68)
    assert_equal(retained_alias.to_string(), "DCC")
    assert_equal(copied.to_string(), "CCC")
    assert_equal(retained_alias.to_string("utf8", 1, 3), "CC")

    var standalone = buffer_alloc(1)
    var slow = buffer_alloc_unsafe_slow(1)
    var threshold = buffer_alloc_unsafe(32)
    assert_true(not standalone.same_storage(rolled))
    assert_true(not slow.same_storage(rolled))
    assert_true(not threshold.same_storage(rolled))
    assert_equal(standalone.get(0), 0)
    set_buffer_pool_size(16)
    var smaller = buffer_alloc_unsafe(1)
    assert_true(smaller.same_storage(rolled))
    assert_true(not buffer_alloc_unsafe(8).same_storage(rolled))
    assert_equal(first.to_string(), "DCC")
    for _ in range(6):
        _ = buffer_alloc_unsafe(1)
    var replacement = buffer_alloc_unsafe(1)
    assert_equal(len(replacement._bytes[]), 16)
    assert_true(not replacement.same_storage(rolled))
    assert_equal(first.to_string(), "DCC")


def allocation_boundaries() raises:
    set_buffer_pool_size(0)
    var first = buffer_alloc_unsafe(1)
    var second = buffer_alloc_unsafe(1)
    assert_true(not first.same_storage(second))
    set_buffer_pool_size(0.5)
    assert_equal(buffer_pool_size(), 0.5)
    assert_equal(len(buffer_alloc_unsafe(2.9)), 2)
    assert_equal(len(buffer_alloc(2.9)), 2)
    assert_equal(len(buffer_alloc_unsafe_slow(2.9)), 2)
    var empty = buffer_alloc_unsafe(0)
    assert_equal(len(empty), 0)
    assert_true(empty != buffer_alloc_unsafe(0))
    assert_equal(len(buffer_concat(List[Buffer](), -1)), 0)
    var invalid_sizes = List[Float64](capacity=5)
    invalid_sizes.append(-1)
    invalid_sizes.append(Float64(FloatLiteral.nan))
    invalid_sizes.append(Float64(FloatLiteral.infinity))
    invalid_sizes.append(-Float64(FloatLiteral.infinity))
    invalid_sizes.append(9007199254740992)
    for invalid in invalid_sizes:
        var rejected = False
        try:
            _ = buffer_alloc_unsafe(invalid)
        except:
            rejected = True
        assert_true(rejected)
        rejected = False
        try:
            _ = buffer_alloc(invalid)
        except:
            rejected = True
        assert_true(rejected)
        rejected = False
        try:
            _ = buffer_alloc_unsafe_slow(invalid)
        except:
            rejected = True
        assert_true(rejected)
    set_buffer_pool_size(-1)
    assert_equal(buffer_pool_size(), -1)
    set_buffer_pool_size(Float64(FloatLiteral.nan))
    assert_equal(len(buffer_alloc_unsafe(1)), 1)


def main() raises:
    var original_size = buffer_pool_size()
    try:
        pool_allocation()
        allocation_boundaries()
    finally:
        set_buffer_pool_size(original_size)
