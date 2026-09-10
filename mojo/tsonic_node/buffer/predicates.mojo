from std.utils import Variant
from tsonic_js import JsValue
from .core import Buffer
from .projection import buffer_brand


def _is_buffer[T: Movable](value: T) -> Bool:
    return T == Buffer


def _is_buffer(value: JsValue) -> Bool:
    return value.has_native_brand(buffer_brand)


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
