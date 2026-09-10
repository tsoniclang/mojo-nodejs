from std.testing import assert_equal, assert_true
from std.collections import List
from std.ffi import external_call
from tsonic_node.os_info import (
    available_parallelism,
    dev_null,
    end_of_line,
    endianness,
    free_memory,
    load_average,
    machine,
    release,
    system_type,
    total_memory,
    uptime,
    version,
)
from tsonic_node.system_errors import (
    get_system_error_message,
    get_system_error_name,
)


def main() raises:
    assert_true(available_parallelism() >= 1)
    assert_equal(
        total_memory(), Float64(external_call["uv_get_total_memory", UInt64]())
    )
    assert_true(free_memory() >= 0)
    assert_true(free_memory() <= total_memory())
    assert_equal(len(load_average()), 3)
    assert_true(uptime() >= 0)
    assert_true(endianness() == "LE" or endianness() == "BE")
    assert_true(len(machine()) > 0)
    assert_true(len(release()) > 0)
    assert_true(len(system_type()) > 0)
    assert_true(len(version()) > 0)
    assert_equal(end_of_line(), "\n")
    assert_equal(dev_null(), "/dev/null")
    assert_equal(get_system_error_name(-2), "ENOENT")
    assert_equal(get_system_error_message(-2), "no such file or directory")
    assert_equal(
        get_system_error_name(-2147483648.0), "Unknown system error -2147483648"
    )
    var invalid_errors = List[Float64](capacity=4)
    invalid_errors.append(0.0)
    invalid_errors.append(1.0)
    invalid_errors.append(-1.5)
    invalid_errors.append(Float64(FloatLiteral.nan))
    for value in invalid_errors:
        var rejected = False
        try:
            _ = get_system_error_name(value)
        except:
            rejected = True
        assert_true(rejected)
