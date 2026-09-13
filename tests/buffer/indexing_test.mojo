from std.testing import assert_equal, assert_false
from tsonic_node.buffer import Buffer


def main() raises:
    var original = Buffer.from_string("abc")
    var view = original.subarray(1)
    view.set_index(0, Optional[Float64](258))
    assert_equal(original.get_index(1).value(), 2)
    view.set_index(0, Optional[Float64](-1))
    assert_equal(original.get_index(1).value(), 255)
    view.set_index(0, None)
    assert_equal(original.get_index(1).value(), 0)
    view.set_index(-0.0, Optional[Float64](97.75))
    assert_equal(original.get_index(1).value(), 97)
    var invalid_indices: List[Float64] = [
        -1,
        0.5,
        2,
        Float64("inf"),
        Float64("nan"),
    ]
    for invalid in invalid_indices:
        assert_false(view.get_index(invalid))
        view.set_index(invalid, Optional[Float64](99))
    assert_equal(original.to_string(), "aac")
    view.set_index(0, Optional[Float64](Float64("nan")))
    assert_equal(view.get_index(0).value(), 0)
