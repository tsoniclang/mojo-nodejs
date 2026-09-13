from std.testing import assert_equal, assert_true
from tsonic_node.assertions import (
    strict_equal,
    strict_equal_with_message,
    not_strict_equal,
    not_strict_equal_with_message,
)
from tsonic_node.buffer import Buffer


def main() raises:
    var nan = Float64(FloatLiteral.nan)
    strict_equal(nan, nan)
    not_strict_equal(Float64(-0.0), Float64(0.0))
    strict_equal(Float32(FloatLiteral.nan), Float32(FloatLiteral.nan))
    strict_equal(Float16(FloatLiteral.nan), Float16(FloatLiteral.nan))
    var greatest = UInt64(18446744073709551615)
    strict_equal(greatest, greatest)
    not_strict_equal(greatest, greatest - 1)
    var rejected = False
    try:
        strict_equal_with_message(
            Float64(-0.0), Float64(0.0), "different zeros"
        )
    except error:
        rejected = True
        assert_equal(String(error), "different zeros")
    assert_true(rejected)
    rejected = False
    try:
        not_strict_equal_with_message(nan, nan, "same NaN")
    except error:
        rejected = True
        assert_equal(String(error), "same NaN")
    assert_true(rejected)
    var bytes = Buffer.from_string("same bytes")
    var retained = bytes
    var different = Buffer.from_string("same bytes")
    strict_equal(bytes, retained)
    not_strict_equal(bytes, different)
