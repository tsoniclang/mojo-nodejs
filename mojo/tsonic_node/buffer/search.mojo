from std.collections import List, Span
from tsonic_runtime.numeric import source_number_to_uint32


def search_offset(value: Optional[Float64], length: Int, reverse: Bool) -> Int:
    if not value or value.value() != value.value():
        return length if reverse else 0
    var number = value.value()
    var result = Int(min(max(number, -2147483648), 2147483647))
    if result < 0:
        result += length
    return result


def _unit(bytes: Span[Byte, _], index: Int, width: Int) -> UInt16:
    var result = UInt16(bytes[index * width])
    if width == 2:
        result |= UInt16(bytes[index * width + 1]) << 8
    return result


def search_bytes(
    haystack: Span[Byte, _],
    needle: Span[Byte, _],
    byte_offset: Optional[Float64],
    reverse: Bool,
    wide: Bool,
) -> Float64:
    var offset = search_offset(byte_offset, len(haystack), reverse)
    if len(needle) == 0:
        return Float64(min(max(offset, 0), len(haystack)))
    if reverse and offset < 0:
        return -1
    if not reverse:
        offset = max(offset, 0)
    var width = 2 if wide else 1
    var count = len(needle) // width
    var length = len(haystack) // width
    if count == 0 or count > length:
        return -1
    if not reverse and offset + len(needle) > len(haystack):
        return -1
    var first = 0 if reverse else offset // width
    var last_start = (
        min(offset // width, length - count) if reverse else length - count
    )
    var end = last_start + count
    var prefixes = List[Int](capacity=count)
    prefixes.append(0)
    var prefix = 0
    for index in range(1, count):
        var next_unit = _unit(needle, index, width)
        while prefix > 0 and next_unit != _unit(needle, prefix, width):
            prefix = prefixes[prefix - 1]
        if next_unit == _unit(needle, prefix, width):
            prefix += 1
        prefixes.append(prefix)
    var matched = 0
    var result = -1
    for index in range(first, end):
        var next_unit = _unit(haystack, index, width)
        while matched > 0 and next_unit != _unit(needle, matched, width):
            matched = prefixes[matched - 1]
        if next_unit == _unit(needle, matched, width):
            matched += 1
        if matched == count:
            result = (index - count + 1) * width
            if not reverse:
                return Float64(result)
            matched = prefixes[matched - 1]
    return Float64(result)


def search_number(
    haystack: Span[Byte, _],
    value: Float64,
    byte_offset: Optional[Float64],
    reverse: Bool,
) -> Float64:
    var needle = Byte(source_number_to_uint32(value) & 255)
    var offset = search_offset(byte_offset, len(haystack), reverse)
    if reverse:
        offset = min(offset, len(haystack) - 1)
        while offset >= 0:
            if haystack[offset] == needle:
                return Float64(offset)
            offset -= 1
    else:
        for index in range(max(offset, 0), len(haystack)):
            if haystack[index] == needle:
                return Float64(index)
    return -1
