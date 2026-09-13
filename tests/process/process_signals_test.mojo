from std.testing import assert_equal, assert_true
from tsonic_node.process import process_id
from tsonic_node.signals import (
    convert_process_signal_to_exit_code,
    kill_named,
    kill_number,
    signal_number,
)


def main() raises:
    assert_equal(convert_process_signal_to_exit_code("SIGTERM"), 143.0)
    assert_equal(signal_number("sigterm"), signal_number("SIGTERM"))
    assert_true(kill_number(Float64(process_id()), 0))
    var invalid_names: List[String] = ["not-a-signal", "", "SIGTERM\x00SIGKILL"]
    for name in invalid_names:
        var failed = False
        try:
            _ = kill_named(Float64(process_id()), name)
        except:
            failed = True
        assert_true(failed)
    var invalid_values: List[Float64] = [
        0.5,
        Float64("NaN"),
        Float64("Infinity"),
        2147483648.0,
    ]
    for value in invalid_values:
        var failed = False
        try:
            _ = kill_number(Float64(process_id()), value)
        except:
            failed = True
        assert_true(failed)
        failed = False
        try:
            _ = kill_number(value, 0)
        except:
            failed = True
        assert_true(failed)
