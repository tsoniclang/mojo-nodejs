from std.sys import argv
from std.testing import assert_equal
from tsonic_node.process import arguments, argument_zero, executable_path


def main() raises:
    var native_arguments = argv()
    var node_arguments = arguments()
    var executable = executable_path()
    assert_equal(len(node_arguments), len(native_arguments) + 1)
    assert_equal(node_arguments[0], executable)
    assert_equal(node_arguments[1], executable)
    assert_equal(argument_zero(), String(native_arguments[0]))
    for index in range(1, len(native_arguments)):
        assert_equal(node_arguments[index + 1], String(native_arguments[index]))
