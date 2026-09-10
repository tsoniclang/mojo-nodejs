from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node.buffer import (
    Buffer,
    buffer_atob,
    buffer_btoa,
    buffer_byte_length,
    buffer_from_numbers,
    buffer_from_string_encoded,
    buffer_is_encoding,
)


def main() raises:
    assert_equal(
        buffer_from_string_encoded("00ffab", "HEX").to_string("hex"), "00ffab"
    )
    assert_equal(
        buffer_from_string_encoded("abXXcd", "hex").to_string("hex"), "ab"
    )
    assert_equal(
        buffer_from_string_encoded("abc", "hex").to_string("hex"), "ab"
    )
    assert_equal(buffer_byte_length("abXX", "hex"), 2)
    assert_equal(
        buffer_from_string_encoded(" Y W\nJj$", "base64").to_string(), "abc"
    )
    assert_equal(buffer_from_string_encoded("_w", "base64url").get(0), 255)
    assert_equal(
        buffer_from_string_encoded("ff", "hex").to_string("base64url"), "_w"
    )
    assert_equal(buffer_btoa("éÿ"), "6f8=")
    assert_equal(buffer_atob("6f8="), "éÿ")
    assert_equal(buffer_atob(" YWJj\n"), "abc")
    assert_equal(
        buffer_from_string_encoded("é", "latin1").to_string("hex"), "e9"
    )
    assert_equal(
        buffer_from_string_encoded("ff", "hex").to_string("ascii"), "\x7f"
    )
    assert_equal(
        buffer_from_string_encoded("ff", "hex").to_string("latin1"), "ÿ"
    )
    assert_equal(
        buffer_from_string_encoded("😀", "utf16le").to_string("hex"), "3dd800de"
    )
    assert_equal(
        buffer_from_string_encoded("3dd800de", "hex").to_string("ucs2"), "😀"
    )
    assert_equal(
        buffer_from_string_encoded("😀", "latin1").to_string("hex"), "3d00"
    )
    assert_equal(buffer_byte_length("😀", "utf8"), 4)
    assert_equal(buffer_byte_length("😀", "latin1"), 2)
    assert_equal(buffer_byte_length("😀", "utf16le"), 4)
    assert_equal(
        buffer_from_string_encoded("f0288cbc", "hex").to_string(), "�(��"
    )
    assert_equal(buffer_from_string_encoded("e282", "hex").to_string(), "�")
    assert_true(buffer_is_encoding("UTF-16LE"))
    assert_true(buffer_is_encoding("base64url"))
    assert_false(buffer_is_encoding("unknown"))
    var rejected = 0
    try:
        _ = buffer_btoa("😀")
    except:
        rejected += 1
    try:
        _ = buffer_atob("abc$")
    except:
        rejected += 1
    try:
        _ = buffer_atob("A")
    except:
        rejected += 1
    try:
        _ = buffer_from_string_encoded("00d8", "hex").to_string("utf16le")
    except:
        rejected += 1
    assert_equal(rejected, 4)
    var values = List[Float64]()
    values.append(Float64(FloatLiteral.nan))
    values.append(Float64(FloatLiteral.infinity))
    values.append(-1)
    values.append(257.9)
    assert_equal(buffer_from_numbers(values).to_string("hex"), "0000ff01")
