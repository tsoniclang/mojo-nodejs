from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import (
    arch,
    arguments,
    current_directory,
    end_of_line,
    environment,
    home_directory,
    host_name,
    platform,
    set_environment,
    temp_directory,
    unset_environment,
)


def main() raises:
    assert_true(temp_directory())
    assert_true(home_directory())
    assert_true(host_name())
    assert_true(platform() == "linux" or platform() == "darwin")
    assert_true(arch() != "unknown")
    assert_equal(end_of_line(), "\n")
    assert_true(current_directory())
    assert_true(len(arguments()) >= 1)

    var name = "TSONIC_MOJO_NODE_TEST_VALUE"
    unset_environment(name)
    assert_false(Bool(environment(name)))
    set_environment(name, "present")
    assert_equal(environment(name).value(), "present")
    unset_environment(name)
    assert_false(Bool(environment(name)))
