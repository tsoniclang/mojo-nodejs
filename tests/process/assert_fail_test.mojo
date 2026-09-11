from std.testing import assert_equal, assert_true
from tsonic_runtime import TsError
from tsonic_node.assertions import fail, fail_error


def main() raises:
    var caught = False
    try:
        fail()
    except error:
        caught = True
        assert_equal(error.name, "AssertionError")
        assert_equal(error.message, "Failed")
    assert_true(caught)
    caught = False
    try:
        fail("unreachable")
    except error:
        caught = True
        assert_equal(error.name, "AssertionError")
        assert_equal(error.message, "unreachable")
    assert_true(caught)
    var original = TsError("TypeError", "retained", Optional[String]("trace"))
    caught = False
    try:
        fail_error(original)
    except error:
        caught = True
        assert_equal(error.name, original.name)
        assert_equal(error.message, original.message)
        assert_equal(error.stack, original.stack)
    assert_true(caught)
