from std.collections import List
from tsonic_js import JsString, JsValue
from tsonic_js.inspection import inspect_value
from tsonic_js.json.operations import json_stringify_for_inspection
from tsonic_js.number import number_parse_float, number_parse_int
from tsonic_js.value import js_value_to_string


def format(values: List[JsValue]) raises -> String:
    if not len(values):
        return String()
    var result = JsString()
    var argument = 0
    if values[0].is_string():
        var template = values[0]._string_value()
        argument = 1
        var segment = 0
        var cursor = 0
        while len(values) > 1 and cursor + 1 < len(template):
            if template.code_unit_at(cursor).value() != 37:
                cursor += 1
                continue
            var specifier = template.code_unit_at(cursor + 1).value()
            if specifier == 37:
                result += template.slice(Float64(segment), Float64(cursor + 1))
            elif argument < len(values) and (
                specifier == 115
                or specifier == 100
                or specifier == 105
                or specifier == 102
                or specifier == 106
                or specifier == 111
                or specifier == 79
                or specifier == 99
            ):
                result += template.slice(Float64(segment), Float64(cursor))
                result += _substitute(specifier, values[argument])
                argument += 1
            else:
                cursor += 1
                continue
            cursor += 2
            segment = cursor
        result += template.slice(Float64(segment))
    while argument < len(values):
        if argument:
            result += JsString(" ")
        var value = values[argument]
        result += value._string_value() if value.is_string() else JsString(
            inspect_value(value)
        )
        argument += 1
    return result.to_native_strict()


def _substitute(specifier: UInt16, value: JsValue) raises -> JsString:
    if specifier == 99:
        return JsString()
    if specifier == 106:
        return json_stringify_for_inspection(value)
    if specifier == 111:
        return JsString(inspect_value(value, 4, 100, True))
    if specifier == 79:
        return JsString(inspect_value(value))
    if specifier == 115:
        if value.is_number() or value.is_bigint():
            return JsString(inspect_value(value))
        if value.is_array() or (value.is_object() and not value.is_byte_view()):
            return JsString(inspect_value(value, 0))
        return js_value_to_string(value)
    if value.is_symbol():
        return JsString("NaN")
    if value.is_bigint() and specifier != 102:
        return JsString(inspect_value(value))
    var number = Float64(FloatLiteral.nan)
    if specifier == 100:
        if value.is_number():
            number = value._number_value()
        elif value.is_null():
            number = 0
        elif value.is_bool():
            number = Float64(value._bool_value())
        elif not value.is_undefined():
            number = _number(js_value_to_string(value))
    elif specifier == 105:
        number = number_parse_int(js_value_to_string(value), 10)
    else:
        number = number_parse_float(js_value_to_string(value))
    return JsString(inspect_value(JsValue(number)))


def _number(value: JsString) -> Float64:
    var text = value.trim()
    if not len(text):
        return 0
    if text == JsString("Infinity") or text == JsString("+Infinity"):
        return Float64(FloatLiteral.infinity)
    if text == JsString("-Infinity"):
        return -Float64(FloatLiteral.infinity)
    if len(text) > 2 and text.code_unit_at(0).value() == 48:
        var prefix = text.code_unit_at(1).value()
        var base = (
            16 if prefix == 120
            or prefix == 88 else 8 if prefix == 111
            or prefix == 79 else 2 if prefix == 98
            or prefix == 66 else 0
        )
        if base:
            var result = 0.0
            for index in range(2, len(text)):
                var unit = Int(text.code_unit_at(index).value())
                var digit = (
                    unit - 48 if unit >= 48
                    and unit <= 57 else unit - 65 + 10 if unit >= 65
                    and unit <= 70 else unit - 97 + 10 if unit >= 97
                    and unit <= 102 else -1
                )
                if digit < 0 or digit >= base:
                    return Float64(FloatLiteral.nan)
                result = result * Float64(base) + Float64(digit)
            return result
    var index = 0
    if (
        text.code_unit_at(index).value() == 43
        or text.code_unit_at(index).value() == 45
    ):
        index += 1
    var digits = 0
    while index < len(text) and _digit(text, index):
        index += 1
        digits += 1
    if index < len(text) and text.code_unit_at(index).value() == 46:
        index += 1
        while index < len(text) and _digit(text, index):
            index += 1
            digits += 1
    if not digits:
        return Float64(FloatLiteral.nan)
    if index < len(text) and (
        text.code_unit_at(index).value() == 101
        or text.code_unit_at(index).value() == 69
    ):
        index += 1
        if index < len(text) and (
            text.code_unit_at(index).value() == 43
            or text.code_unit_at(index).value() == 45
        ):
            index += 1
        var start = index
        while index < len(text) and _digit(text, index):
            index += 1
        if index == start:
            return Float64(FloatLiteral.nan)
    if index != len(text):
        return Float64(FloatLiteral.nan)
    try:
        return atof(text.to_native_strict())
    except:
        return Float64(FloatLiteral.nan)


def _digit(text: JsString, index: Int) -> Bool:
    var unit = text.code_unit_at(index).value()
    return unit >= 48 and unit <= 57
