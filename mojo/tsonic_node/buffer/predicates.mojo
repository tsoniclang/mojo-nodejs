from tsonic_js import JsValue
from .projection import buffer_brand


def buffer_is_buffer(value: JsValue) -> Bool:
    return value.has_native_brand(buffer_brand)
