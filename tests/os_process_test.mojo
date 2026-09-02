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
from tsonic_node.process import (
    argument_zero,
    hrtime,
    hrtime_since,
    memory_usage,
    process_id,
    stderr,
    stdout,
    uptime,
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
    assert_true(argument_zero())
    assert_equal(len(hrtime()), 2)
    assert_equal(len(hrtime_since(hrtime())), 2)
    assert_true(memory_usage().rss >= 0)
    assert_true(process_id() > 0)
    assert_true(uptime() >= 0)
    assert_equal(stdout().fd(), 1)
    assert_equal(stderr().fd(), 2)

    var name = "TSONIC_MOJO_NODE_TEST_VALUE"
    unset_environment(name)
    assert_false(Bool(environment(name)))
    set_environment(name, "present")
    assert_equal(environment(name).value(), "present")
    unset_environment(name)
    assert_false(Bool(environment(name)))
