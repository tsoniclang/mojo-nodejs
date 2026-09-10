from std.collections import List
from std.sys import CompilationTarget
from tsonic_js import JsRegExp, JsString
from .syntax import GlobSyntax
from .braces import expand_braces
from .components import split_components, normalize_components, pattern_components, is_drive, strip_drive_namespace
from .limits import pattern_limit, match_limit, require_source_size


@fieldwise_init
struct _Component(ImplicitlyCopyable):
    var globstar: Bool
    var literal: Optional[String]
    var expression: Optional[JsRegExp]

    def matches(self, value: String) raises -> Bool:
        if self.literal:
            return self.literal.value() == value
        return self.expression.value().test_native(value)


def _compile(pattern: List[String]) raises -> List[_Component]:
    var result = List[_Component]()
    var size = 0
    for part in pattern:
        if part == "**":
            result.append(_Component(True, None, None))
            continue
        var syntax = GlobSyntax(part)
        var literal = syntax.literal()
        if literal:
            result.append(_Component(False, Optional(literal.value().to_native_strict()), None))
            continue
        var expression = "^(?:" + syntax.expression() + ")$"
        size += expression.byte_length()
        require_source_size(size)
        var flags = "u" if syntax.unicode else ""
        comptime if CompilationTarget.is_macos():
            flags += "i"
        result.append(_Component(False, None, Optional(JsRegExp(JsString(expression), JsString(flags)))))
    return result^


def _match(path: List[String], pattern: List[_Component]) raises -> Bool:
    var states = List[Bool]()
    for index in range(len(path) + 1):
        states.append(index == 0)
    for component in pattern:
        var next = List[Bool]()
        for index in range(len(path) + 1):
            next.append(False)
        if component.globstar:
            for index in range(len(path)):
                next[index] = next[index] or states[index]
                if next[index] and not path[index].startswith("."):
                    next[index + 1] = True
        else:
            for index in range(len(path)):
                if states[index] and component.matches(path[index]):
                    next[index + 1] = True
        states = next^
    return states[len(path)] or (len(path) > 0 and not path[len(path) - 1] and states[len(path) - 1])


def matches_glob(path: String, pattern: String, windows: Bool = False) raises -> Bool:
    if pattern.byte_length() > pattern_limit * 3 or len(JsString(pattern)) > pattern_limit:
        raise Error("Path glob pattern exceeds 65536 UTF-16 code units")
    if not pattern:
        return not path
    var input = path.replace("\\", "/") if windows else path
    var file = normalize_components(split_components(input, windows), False)
    var remaining = match_limit
    if windows:
        strip_drive_namespace(file)
    for alternative in expand_braces(pattern.replace("\\", "/")):
        for parts in pattern_components(alternative, windows):
            var selected = parts.copy()
            if windows:
                strip_drive_namespace(selected)
                if len(file) and len(selected) and is_drive(file[0]) and is_drive(selected[0]):
                    selected[0] = selected[0].lower()
                    file[0] = file[0].lower()
            if len(file) > remaining // max(1, len(selected)):
                raise Error("Path glob component-match budget exceeded")
            remaining -= len(file) * len(selected)
            if _match(file, _compile(selected)):
                return True
    return False
