from std.collections import List
from tsonic_runtime.numeric import source_number_to_uint32
from ..validation import checked_integer
from .core import Buffer
from .codec import encode_bytes, encoded_byte_length, is_encoding, encode_binary_string, decode_binary_string, transcode_bytes


def buffer_from_string(value: String) -> Buffer:
    return Buffer.from_string(value)


def buffer_from_string_encoded(value: String, encoding: String) raises -> Buffer:
    return Buffer(encode_bytes(value, encoding))


def buffer_from_numbers(values: List[Float64]) -> Buffer:
    var bytes = List[Byte](capacity=len(values))
    for value in values:
        bytes.append(Byte(source_number_to_uint32(value) & 255))
    return Buffer(bytes^)


def buffer_from_buffer(value: Buffer) -> Buffer:
    return Buffer(value.copy_bytes())


def buffer_alloc(size: Float64) raises -> Buffer:
    if not (size >= 0 and size <= 9007199254740991):
        raise Error("Buffer size is outside the valid range")
    return Buffer.allocate(Int(size))


def buffer_alloc_number(size: Float64, fill: Float64) raises -> Buffer:
    var result = buffer_alloc(size)
    return result.fill_number(fill)


def buffer_alloc_string(size: Float64, fill: String, encoding: String = "utf8") raises -> Buffer:
    var result = buffer_alloc(size)
    if len(result) == 0:
        return result
    return result.fill_string(fill, 0, None, encoding)


def buffer_alloc_buffer(size: Float64, fill: Buffer) raises -> Buffer:
    var result = buffer_alloc(size)
    return result.fill_buffer(fill)


def buffer_concat(values: List[Buffer], total_length: Optional[Float64] = None) raises -> Buffer:
    var length = 0
    if total_length:
        length = Int(checked_integer(total_length.value(), 9007199254740991, "totalLength"))
    else:
        for value in values:
            if len(value) > 9007199254740991 - length:
                raise Error("Buffer concatenation exceeds the supported length")
            length += len(value)
    var result = Buffer.allocate(length)
    var offset = 0
    for value in values:
        if offset >= length:
            break
        offset += Int(value.copy(result, Float64(offset)))
    return result


def buffer_compare(left: Buffer, right: Buffer) -> Float64:
    return left.compare(right)


def buffer_byte_length(value: String, encoding: String = "utf8") raises -> Float64:
    return encoded_byte_length(value, encoding)


def buffer_byte_length_buffer(value: Buffer) -> Float64:
    return value.js_length()


def buffer_is_encoding(encoding: String) -> Bool:
    return is_encoding(encoding)


def buffer_is_ascii(value: Buffer) -> Bool:
    return value.is_ascii()


def buffer_is_utf8(value: Buffer) -> Bool:
    return value.is_utf8()


def buffer_transcode(value: Buffer, source_encoding: String, target_encoding: String) raises -> Buffer:
    return Buffer(transcode_bytes(value.copy_bytes(), source_encoding, target_encoding))


def buffer_btoa(value: String) raises -> String:
    return encode_binary_string(value)


def buffer_atob(value: String) raises -> String:
    return decode_binary_string(value)
