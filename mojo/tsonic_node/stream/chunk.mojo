from std.utils import Variant
from ..buffer import Buffer


comptime StreamChunk = Variant[Buffer, String]


def chunk_text(value: StreamChunk) raises -> String:
    if value.isa[String]():
        return value.unsafe_get[String]()
    return value.unsafe_get[Buffer]().to_string()
