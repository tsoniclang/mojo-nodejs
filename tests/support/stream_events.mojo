from std.testing import assert_true
from tsonic_node.stream.completion import poll_streams


def require_unhandled_stream_error(fragment: String) raises:
    var rejected = False
    try:
        _ = poll_streams()
    except error:
        assert_true(fragment in String(error))
        rejected = True
    assert_true(rejected)
    _ = poll_streams()
