from std.base64 import b64encode
from std.collections import List, Span
from std.collections.string import Codepoint
from tsonic_js.string import JsString


def encoding_name(value: String) raises -> String:
    var name = value.lower()
    if name == "utf8" or name == "utf-8":
        return "utf8"
    if (
        name == "ucs2"
        or name == "ucs-2"
        or name == "utf16le"
        or name == "utf-16le"
    ):
        return "utf16le"
    if name == "binary" or name == "latin1":
        return "latin1"
    if (
        name == "ascii"
        or name == "hex"
        or name == "base64"
        or name == "base64url"
    ):
        return name
    raise Error("Unsupported Buffer encoding: ", value)


def is_encoding(value: String) -> Bool:
    try:
        _ = encoding_name(value)
        return True
    except:
        return False


def _hex_digit(value: UInt8) -> Int:
    if value >= 48 and value <= 57:
        return Int(value - 48)
    if value >= 65 and value <= 70:
        return Int(value - 65) + 10
    if value >= 97 and value <= 102:
        return Int(value - 97) + 10
    return -1


def _base64_digit(value: UInt8) -> Int:
    if value >= 65 and value <= 90:
        return Int(value - 65)
    if value >= 97 and value <= 122:
        return Int(value - 97) + 26
    if value >= 48 and value <= 57:
        return Int(value - 48) + 52
    if value == 43 or value == 45:
        return 62
    if value == 47 or value == 95:
        return 63
    return -1


def encode_bytes(value: String, encoding: String) raises -> List[Byte]:
    var name = encoding_name(encoding)
    var result = List[Byte]()
    if name == "utf8":
        for byte in value.as_bytes():
            result.append(byte)
    elif name == "hex":
        var bytes = value.as_bytes()
        var index = 0
        while index + 1 < len(bytes):
            var high = _hex_digit(UInt8(bytes[index]))
            var low = _hex_digit(UInt8(bytes[index + 1]))
            if high < 0 or low < 0:
                break
            result.append(Byte((high << 4) | low))
            index += 2
    elif name == "base64" or name == "base64url":
        var accumulator = UInt32(0)
        var bits = 0
        for byte in value.as_bytes():
            if byte == 61:
                break
            var digit = _base64_digit(UInt8(byte))
            if digit < 0:
                continue
            accumulator = (accumulator << 6) | UInt32(digit)
            bits += 6
            if bits >= 8:
                bits -= 8
                result.append(Byte((accumulator >> UInt32(bits)) & 255))
    else:
        var units = JsString(value)
        for index in range(len(units)):
            var unit = units.code_unit_at(index).value()
            result.append(Byte(unit & 255))
            if name == "utf16le":
                result.append(Byte(unit >> 8))
    return result^


def decode_bytes(bytes: List[Byte], encoding: String) raises -> String:
    var name = encoding_name(encoding)
    if name == "utf8":
        return String(from_utf8_lossy=Span(bytes))
    if name == "base64" or name == "base64url":
        var text = b64encode(Span(bytes))
        if name == "base64url":
            text = text.replace("+", "-").replace("/", "_").replace("=", "")
        return text
    if name == "hex":
        comptime digits = "0123456789abcdef"
        var result = String(capacity_bytes=len(bytes) * 2)
        for byte in bytes:
            result += String(digits[byte=Int(UInt8(byte) >> 4)])
            result += String(digits[byte=Int(UInt8(byte) & 15)])
        return result
    if name == "utf16le":
        var units = List[UInt16](capacity=len(bytes) // 2)
        var index = 0
        while index + 1 < len(bytes):
            units.append(UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
            index += 2
        return JsString(code_units=units^).to_native_strict()
    var result = String()
    for byte in bytes:
        var scalar = UInt32(byte) & 127 if name == "ascii" else UInt32(byte)
        result += String(Codepoint(unsafe_unchecked_codepoint=scalar))
    return result


def encoded_byte_length(value: String, encoding: String) raises -> Float64:
    var name = encoding_name(encoding)
    if name == "utf8":
        return Float64(value.byte_length())
    var length = len(JsString(value))
    if name == "utf16le":
        return Float64(length * 2)
    if name == "hex":
        return Float64(length // 2)
    if name == "base64" or name == "base64url":
        if length > 0 and value.endswith("="):
            length -= 1
            if length > 0 and value.endswith("=="):
                length -= 1
        return Float64(length * 3 // 4)
    return Float64(length)


def encode_binary_string(value: String) raises -> String:
    for point in value.codepoints():
        if point.to_u32() > 255:
            raise Error(
                "btoa input contains a character outside the byte range"
            )
    return decode_bytes(encode_bytes(value, "latin1"), "base64")


def decode_binary_string(value: String) raises -> String:
    var compact = String()
    for byte in value.as_bytes():
        if byte == 9 or byte == 10 or byte == 12 or byte == 13 or byte == 32:
            continue
        compact += String(Codepoint(unsafe_unchecked_codepoint=UInt32(byte)))
    var end = compact.byte_length()
    var bytes = compact.as_bytes()
    if end % 4 == 0:
        if end > 0 and bytes[end - 1] == 61:
            end -= 1
        if end > 0 and bytes[end - 1] == 61:
            end -= 1
    if end % 4 == 1:
        raise Error("atob input has an invalid encoded length")
    for index in range(end):
        var byte = UInt8(bytes[index])
        if _base64_digit(byte) < 0 or byte == 45 or byte == 95:
            raise Error("atob input contains an invalid base64 character")
    return decode_bytes(
        encode_bytes(String(compact[byte=:end]), "base64"), "latin1"
    )


def writable_byte_count(
    bytes: List[Byte], maximum: Int, encoding: String
) -> Int:
    var count = min(maximum, len(bytes))
    if encoding == "utf16le":
        return count - count % 2
    if encoding == "utf8" and count < len(bytes):
        while count > 0 and UInt8(bytes[count]) & 0xC0 == 0x80:
            count -= 1
    return count


def transcode_bytes(
    bytes: List[Byte], source_encoding: String, target_encoding: String
) raises -> List[Byte]:
    var source = encoding_name(source_encoding)
    var target = encoding_name(target_encoding)
    for name in (source, target):
        if (
            name != "utf8"
            and name != "utf16le"
            and name != "latin1"
            and name != "ascii"
        ):
            raise Error("Buffer.transcode requires a text encoding")
    var units = List[UInt16]()
    if source == "utf16le":
        var index = 0
        while index + 1 < len(bytes):
            units.append(UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
            index += 2
        if index < len(bytes):
            units.append(0xFFFD)
    elif source == "ascii":
        for byte in bytes:
            units.append(UInt16(byte) if byte < 128 else 0xFFFD)
    else:
        var text = JsString(decode_bytes(bytes, source))
        for index in range(len(text)):
            units.append(text.code_unit_at(index).value())
    var text = JsString(code_units=units^).to_native_lossy()
    if target == "utf8" or target == "utf16le":
        return encode_bytes(text, target)
    var result = List[Byte]()
    var maximum = UInt32(127) if target == "ascii" else UInt32(255)
    for point in text.codepoints():
        var scalar = point.to_u32()
        result.append(Byte(scalar if scalar <= maximum else 63))
    return result^
