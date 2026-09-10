from std.collections import List
from std.memory import Span
from tsonic_js import JsString


def escaped_unit(unit: UInt16) -> String:
    var digits = String("0123456789abcdef").as_bytes()
    var output = List[UInt8]()
    output.append(92)
    output.append(117)
    for shift in range(3, -1, -1):
        output.append(digits[(Int(unit) >> (shift * 4)) & 15])
    return String(unsafe_from_utf8=Span(output))


@fieldwise_init
struct CharacterClass(ImplicitlyCopyable):
    var source: String
    var end: Int
    var unicode: Bool
    var literal: Optional[UInt16]


@fieldwise_init
struct _Category(ImplicitlyCopyable):
    var name: String
    var expression: String
    var unicode: Bool
    var complement: Bool


def _categories() -> List[_Category]:
    return [
        _Category("alnum", "\\p{L}\\p{Nl}\\p{Nd}", True, False),
        _Category("alpha", "\\p{L}\\p{Nl}", True, False),
        _Category("ascii", "\\x00-\\x7f", False, False),
        _Category("blank", "\\p{Zs}\\t", True, False),
        _Category("cntrl", "\\p{Cc}", True, False),
        _Category("digit", "\\p{Nd}", True, False),
        _Category("graph", "\\p{Z}\\p{C}", True, True),
        _Category("lower", "\\p{Ll}", True, False),
        _Category("print", "\\p{C}", True, False),
        _Category("punct", "\\p{P}", True, False),
        _Category("space", "\\p{Z}\\t\\r\\n\\v\\f", True, False),
        _Category("upper", "\\p{Lu}", True, False),
        _Category("word", "\\p{L}\\p{Nl}\\p{Nd}\\p{Pc}", True, False),
        _Category("xdigit", "A-Fa-f0-9", False, False),
    ]


def parse_class(pattern: JsString, start: Int) -> Optional[CharacterClass]:
    var index = start + 1
    var negated = index < len(pattern) and (
        pattern.code_unit_at(index).value() == 33
        or pattern.code_unit_at(index).value() == 94
    )
    if negated:
        index += 1
    var beginning = index
    var positives = String()
    var negatives = String()
    var unicode = False
    var count = 0
    var literal = Optional[UInt16](None)
    while index < len(pattern):
        var unit = pattern.code_unit_at(index).value()
        if unit == 93 and index > beginning:
            if not positives and not negatives:
                return Optional(
                    CharacterClass("(?!)", index + 1, unicode, None)
                )
            if count == 1 and literal and not negated:
                return Optional(
                    CharacterClass(
                        escaped_unit(literal.value()),
                        index + 1,
                        unicode,
                        literal,
                    )
                )
            var source = String()
            if positives:
                source = "[" + ("^" if negated else "") + positives + "]"
            if negatives:
                var inverse = "[" + ("" if negated else "^") + negatives + "]"
                source = (
                    "(?:" + source + "|" + inverse + ")" if source else inverse
                )
            return Optional(CharacterClass(source^, index + 1, unicode, None))
        var category = False
        if unit == 91:
            for entry in _categories():
                var name = JsString("[:" + entry.name + ":]")
                if (
                    pattern.slice(Float64(index), Float64(index + len(name)))
                    == name
                ):
                    if entry.complement:
                        negatives += entry.expression
                    else:
                        positives += entry.expression
                    unicode = unicode or entry.unicode
                    count += 2
                    index += len(name)
                    category = True
                    break
        if category:
            continue
        if (
            index + 2 < len(pattern)
            and pattern.code_unit_at(index + 1).value() == 45
            and pattern.code_unit_at(index + 2).value() != 93
        ):
            var ending = pattern.code_unit_at(index + 2).value()
            if (
                ending == 91
                and index + 3 < len(pattern)
                and pattern.code_unit_at(index + 3).value() == 58
            ):
                return Optional(
                    CharacterClass("(?!)", len(pattern), unicode, None)
                )
            if ending > unit:
                positives += escaped_unit(unit) + "-" + escaped_unit(ending)
                count += 2
            elif ending == unit:
                positives += escaped_unit(unit)
                literal = unit
                count += 1
            index += 3
        else:
            positives += escaped_unit(unit)
            literal = unit
            count += 1
            index += 1
    return None
