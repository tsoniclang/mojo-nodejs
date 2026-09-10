from std.collections import List
from std.collections.string import Codepoint
from .limits import require_depth, require_expansion_size, require_source_size


def _integer(text: String) raises -> Optional[Int]:
    var bytes = text.as_bytes()
    var start = 1 if text.startswith("-") else 0
    if start == len(bytes):
        return None
    var value = 0
    for index in range(start, len(bytes)):
        var digit = Int(bytes[index]) - 48
        if digit < 0 or digit > 9:
            return None
        if value > (9007199254740991 - digit) // 10:
            raise Error("Path glob range exceeds exact integer bounds")
        value = value * 10 + digit
    return -value if start else value


def _padded(number: Int, width: Int) -> String:
    var digits = String(abs(number))
    var zeros = max(0, width - digits.byte_length() - (1 if number < 0 else 0))
    return ("-" if number < 0 else "") + "0" * zeros + digits


def _range(body: String) raises -> Optional[List[String]]:
    var parts = List[String]()
    for item in body.split(".."):
        parts.append(String(item))
    if len(parts) != 2 and len(parts) != 3:
        return None
    var first = _integer(parts[0])
    var last = _integer(parts[1])
    var numeric = Bool(first) and Bool(last)
    if not numeric:
        if parts[0].byte_length() != 1 or parts[1].byte_length() != 1:
            return None
        var start_code = Int(parts[0].as_bytes()[0])
        var end_code = Int(parts[1].as_bytes()[0])
        if not ((65 <= start_code <= 90 or 97 <= start_code <= 122) and
                (65 <= end_code <= 90 or 97 <= end_code <= 122)):
            return None
        first = start_code
        last = end_code
    var stride = 1
    if len(parts) == 3:
        var supplied = _integer(parts[2])
        if not supplied:
            return None
        stride = max(1, abs(supplied.value()))
    var start = first.value()
    var stop = last.value()
    var count = abs(stop - start) // stride + 1
    require_expansion_size(count)
    var width = 0
    if numeric:
        for index in range(2):
            var digits = parts[index]
            var offset = 1 if digits.startswith("-") else 0
            if digits.byte_length() > offset + 1 and digits.as_bytes()[offset] == 48:
                width = max(parts[0].byte_length(), parts[1].byte_length())
    var result = List[String]()
    for index in range(count):
        var value = start + (index * stride if stop >= start else -index * stride)
        if numeric:
            result.append(_padded(value, width))
        else:
            result.append(String() if value == 92 else String(Codepoint(unsafe_unchecked_codepoint=UInt32(value))))
    return Optional(result^)


def _choices(body: String) raises -> Optional[List[String]]:
    var choices = List[String]()
    var depth = 0
    var start = 0
    var bytes = body.as_bytes()
    for index in range(len(bytes)):
        var token = bytes[index]
        if token == 123:
            depth += 1
            require_depth(depth)
        elif token == 125:
            depth -= 1
        elif token == 44 and depth == 0:
            choices.append(String(body[byte=start:index]))
            start = index + 1
    if len(choices):
        choices.append(String(body[byte=start:]))
        require_expansion_size(len(choices))
        return Optional(choices^)
    return _range(body)


@fieldwise_init
struct _Expansion:
    var text: String
    var scan: Int


def expand_braces(pattern: String) raises -> List[String]:
    var pending = List[_Expansion]()
    pending.append(_Expansion(pattern, 0))
    var result = List[String]()
    var retained_bytes = pattern.byte_length()
    while len(pending):
        var work = pending.pop()
        retained_bytes -= work.text.byte_length()
        var expanded = False
        var bytes = work.text.as_bytes()
        var opening = work.scan
        while opening < len(bytes):
            if bytes[opening] != 123 or (opening > 0 and bytes[opening - 1] == 36):
                opening += 1
                continue
            var depth = 1
            var closing = opening + 1
            while closing < len(bytes) and depth:
                if bytes[closing] == 123:
                    depth += 1
                    require_depth(depth)
                elif bytes[closing] == 125:
                    depth -= 1
                if depth:
                    closing += 1
            if depth:
                opening += 1
                continue
            var alternatives = _choices(String(work.text[byte=opening + 1:closing]))
            if not alternatives:
                opening += 1
                continue
            var prefix = String(work.text[byte=:opening])
            var suffix = String(work.text[byte=closing + 1:])
            for alternative in alternatives.value():
                var next = prefix + alternative + suffix
                retained_bytes += next.byte_length()
                require_source_size(retained_bytes)
                require_expansion_size(len(result) + len(pending) + 1)
                pending.append(_Expansion(next^, opening))
            expanded = True
            break
        if not expanded and work.text:
            retained_bytes += work.text.byte_length()
            require_source_size(retained_bytes)
            require_expansion_size(len(result) + 1)
            result.append(work.text^)
    return result^
