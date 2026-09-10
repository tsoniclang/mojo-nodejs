from std.collections import List, Span
from tsonic_runtime import Callable, RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_js import JsByteView, JsString, JsValue, js_value_from_native_bytes, js_value_from_array_values, js_value_from_object_entries
from .core import Buffer


comptime buffer_brand = "node:buffer::Buffer"


@fieldwise_init
struct _BufferProjection:
    var source: Buffer

    @staticmethod
    def to_json(context: ErasedCallableContext, var _arguments: Tuple[String]) raises -> JsValue:
        var source = context.unsafe_bitcast[Self]()[].source
        if len(source) > 1048576:
            raise Error("Buffer JSON presentation exceeds its value-node budget")
        var numbers = List[JsValue](capacity=len(source))
        for index in range(len(source)):
            numbers.append(JsValue(Float64(source._bytes[][source._offset + index])))
        var keys = List[JsString]()
        keys.append(JsString("type"))
        keys.append(JsString("data"))
        var values = List[JsValue]()
        values.append(JsValue(JsString("Buffer")))
        values.append(js_value_from_array_values(numbers^))
        return js_value_from_object_entries(keys^, values^)

    @staticmethod
    def to_string(context: ErasedCallableContext, var _arguments: Tuple[]) -> JsString:
        var source = context.unsafe_bitcast[Self]()[].source
        var bytes = Span(source._bytes[])[source._offset:source._offset + source._length]
        return JsString(String(from_utf8_lossy=bytes))

    @staticmethod
    def inspect(context: ErasedCallableContext, var _arguments: Tuple[Int]) -> String:
        var source = context.unsafe_bitcast[Self]()[].source
        var output = String("<Buffer")
        var digits = String("0123456789abcdef")
        for index in range(min(50, len(source))):
            var byte = Int(source._bytes[][source._offset + index])
            output += " " + String(digits[byte=byte >> 4]) + String(digits[byte=byte & 15])
        if len(source) > 50:
            var remaining = len(source) - 50
            output += " ... " + String(remaining) + (" more byte" if remaining == 1 else " more bytes")
        return output + ">"


def buffer_to_js_value(source: Buffer) -> JsValue:
    var environment = allocate_callable_environment(_BufferProjection(source), destroy_callable_environment[_BufferProjection])
    return js_value_from_native_bytes(
        JsByteView(source._bytes, source._offset, source._length, source._identity),
        buffer_brand,
        RaisingCallable[Tuple[String], JsValue, Error](environment, _BufferProjection.to_json),
        Callable[Tuple[], JsString](environment, _BufferProjection.to_string),
        Callable[Tuple[Int], String](environment, _BufferProjection.inspect),
    )
