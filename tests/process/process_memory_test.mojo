from std.ffi import external_call
from std.testing import assert_equal, assert_true
from tsonic_node.process import available_memory, constrained_memory


def main():
    var constrained = constrained_memory()
    assert_equal(
        constrained,
        Float64(external_call["uv_get_constrained_memory", UInt64]()),
    )
    assert_true(constrained >= 0)
    var available = available_memory()
    assert_true(available >= 0)
    if constrained != 0:
        assert_true(available <= constrained)
