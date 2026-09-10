from std.utils import Variant
from ..buffer import Buffer


comptime StreamChunk = Variant[Buffer, String]
