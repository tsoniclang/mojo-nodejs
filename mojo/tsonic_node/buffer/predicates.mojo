from std.utils import Variant
from .core import Buffer


def _is_buffer[T: Movable](value: T) -> Bool:
    return T == Buffer


def _is_buffer[*Members: Movable](value: Variant[*Members]) -> Bool:
    comptime for index in range(Members.length):
        if value.isa[Members[index]]():
            return _is_buffer(value[Members[index]])
    return False


def _is_buffer[Value: Movable](value: Optional[Value]) -> Bool:
    if value:
        return _is_buffer(value.value())
    return False


def buffer_is_buffer[T: Movable](value: T) -> Bool:
    return _is_buffer(value)
