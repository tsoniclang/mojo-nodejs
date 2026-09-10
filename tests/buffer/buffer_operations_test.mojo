from std.collections import List
from std.testing import assert_equal, assert_true
from tsonic_node.buffer import (
    Buffer,
    buffer_alloc,
    buffer_alloc_number,
    buffer_alloc_string,
    buffer_from_buffer,
    buffer_from_numbers,
    buffer_from_string_encoded,
    buffer_concat,
    buffer_is_ascii,
    buffer_is_utf8,
    buffer_transcode,
)


def main() raises:
    var original = Buffer.from_string("abcdef")
    var retained_alias = original.subarray(1, Float64(5))
    assert_equal(original.copy(original, 2, 0, Float64(4)), 4)
    assert_equal(original.to_string(), "ababcd")
    assert_equal(retained_alias.to_string(), "babc")
    assert_equal(original.copy(original, 0, 2), 4)
    assert_equal(original.to_string(), "abcdcd")
    var copied = buffer_from_buffer(original)
    original.set(0, 122)
    assert_equal(copied.to_string(), "abcdcd")
    var rejected = False
    try:
        _ = original.copy(copied, -1)
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        _ = original.copy(copied, 0, 7)
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(original.copy(copied, 100), 0)
    assert_equal(original.slice(-2).to_string(), "cd")
    assert_equal(
        original.slice(Float64(FloatLiteral.nan)).to_string(),
        original.to_string(),
    )

    var buffer = buffer_alloc_number(8, 46)
    assert_equal(buffer.write("😀", 1, Float64(3)), 0)
    assert_equal(buffer.to_string(), "........")
    assert_equal(buffer.write("a😀z", 0, Float64(5)), 5)
    assert_equal(buffer.to_string("utf8", 0, Float64(5)), "a😀")
    assert_equal(buffer.write("💩", 0, Float64(3), "utf16le"), 2)
    assert_equal(buffer.to_string("hex", 0, Float64(2)), "3dd8")
    assert_equal(buffer.write_encoded("aabbz1", "hex"), 2)
    assert_equal(buffer.to_string("hex", 0, Float64(2)), "aabb")
    assert_equal(buffer_alloc_string(5, "abc").to_string(), "abcab")
    _ = buffer.fill_string("", 0, Float64(8))
    assert_equal(buffer.to_string("hex"), "0000000000000000")
    _ = buffer.fill_number(257, 1, Float64(3))
    assert_equal(buffer.to_string("hex"), "0001010000000000")
    _ = buffer.fill_buffer(buffer.subarray(0, Float64(3)), 2, Float64(8))
    assert_equal(buffer.to_string("hex"), "0001000101000101")

    var sequence = Buffer.from_string("ababababa")
    assert_equal(sequence.find_string("ababa"), 0)
    assert_equal(sequence.find_string("ababa", Float64(1)), 2)
    assert_equal(sequence.last_string("ababa"), 4)
    assert_equal(sequence.last_string("ababa", Float64(3)), 2)
    assert_equal(sequence.find_string("", Float64(100)), 9)
    assert_equal(sequence.last_string("", Float64(-100)), 0)
    assert_equal(sequence.last_string("a", Float64(-100)), -1)
    assert_equal(sequence.find_number(353), 0)
    assert_equal(sequence.find_number(98, Float64(-2)), 7)
    assert_true(sequence.includes_buffer(Buffer.from_string("bab")))
    var wide = buffer_from_string_encoded("ababa", "utf16le")
    assert_equal(wide.find_string("ba", Float64(0), "utf16le"), 2)
    assert_equal(wide.last_string("ba", None, "utf16le"), 6)
    assert_equal(wide.find_string("ba", Float64(3), "utf16le"), 2)

    var numbers = buffer_alloc(8)
    _ = numbers.write_int8(-128)
    _ = numbers.write_uint8(255, 1)
    _ = numbers.write_int32_be(-2147483648, 2)
    assert_equal(numbers.read_int8(), -128)
    assert_equal(numbers.read_uint8(1), 255)
    assert_equal(numbers.read_int32_be(2), -2147483648)
    rejected = False
    try:
        _ = numbers.write_uint8(-1)
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        _ = numbers.write_int8(128)
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        _ = numbers.read_uint8(0.5)
    except:
        rejected = True
    assert_true(rejected)
    _ = numbers.write_uint8(Float64(FloatLiteral.nan))
    assert_equal(numbers.read_uint8(), 0)
    assert_true(buffer_is_ascii(Buffer.from_string("ascii")))
    assert_true(not buffer_is_ascii(Buffer.from_string("é")))
    assert_true(buffer_is_utf8(Buffer.from_string("é😀")))
    assert_true(not buffer_is_utf8(buffer_from_string_encoded("c080", "hex")))
    assert_equal(
        buffer_transcode(Buffer.from_string("€é"), "utf8", "ascii").to_string(),
        "??",
    )
    assert_equal(
        buffer_transcode(Buffer.from_string("€é"), "utf8", "latin1").to_string(
            "hex"
        ),
        "3fe9",
    )
    assert_equal(
        buffer_transcode(
            buffer_from_string_encoded("00d8", "hex"), "utf16le", "utf8"
        ).to_string(),
        "�",
    )
    var buffers = List[Buffer]()
    buffers.append(Buffer.from_string("ab"))
    buffers.append(Buffer.from_string("cd"))
    assert_equal(buffer_concat(buffers, Float64(3)).to_string(), "abc")
    assert_equal(
        buffer_concat(buffers, Float64(6)).to_string("hex"), "616263640000"
    )
