from std.testing import assert_true
from tsonic_node.buffer import Buffer
from tsonic_node.stream.chunk import StreamChunk


def require_buffer(value: Optional[StreamChunk]) raises -> Buffer:
    assert_true(Bool(value), "Expected a buffered stream value")
    assert_true(
        value.value().isa[Buffer](),
        "A binary stream unexpectedly returned decoded text",
    )
    return value.value().unsafe_get[Buffer]()


def require_text(value: Optional[StreamChunk]) raises -> String:
    assert_true(Bool(value), "Expected a decoded stream value")
    assert_true(
        value.value().isa[String](),
        "A decoded stream unexpectedly returned a binary Buffer",
    )
    return value.value().unsafe_get[String]()
