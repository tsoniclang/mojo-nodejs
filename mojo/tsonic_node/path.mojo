from std.collections import List
from std.pathlib import cwd


comptime separator = "/"
comptime delimiter = ":"


@fieldwise_init
struct PathParts(Copyable):
    var root: String
    var directory: String
    var base: String
    var name: String
    var extension: String


def _append_component(mut output: String, component: String):
    if output and not output.endswith(separator):
        output += separator
    output += component


def _components(path: String) -> List[String]:
    var result = List[String]()
    for part in path.split(separator):
        var component = String(part)
        if component:
            result.append(component^)
    return result^


def normalize(path: String) -> String:
    if not path:
        return "."

    var absolute = path.startswith(separator)
    var trailing = path.endswith(separator)
    var components = List[String]()

    for part in path.split(separator):
        var component = String(part)
        if not component or component == ".":
            continue
        if component == "..":
            if len(components) and components[len(components) - 1] != "..":
                _ = components.pop()
            elif not absolute:
                components.append(component^)
        else:
            components.append(component^)

    var result = String(separator) if absolute else String()
    for component in components:
        _append_component(result, component)

    if not result:
        result = separator if absolute else "."
    elif trailing and result != separator:
        result += separator
    return result^


def join(*parts: String) -> String:
    if not len(parts):
        return "."
    var combined = String()
    for part in parts:
        if not part:
            continue
        _append_component(combined, part)
    return normalize(combined^)


def resolve(*parts: String) raises -> String:
    var resolved = String()
    var index = len(parts) - 1
    while index >= -1:
        var part = String(cwd()) if index == -1 else parts[index]
        if part:
            if resolved:
                resolved = part + separator + resolved
            else:
                resolved = part
            if part.startswith(separator):
                break
        index -= 1
    var normalized = normalize(resolved^)
    if not normalized.startswith(separator):
        normalized = separator + normalized
    return normalized^


def is_absolute(path: String) -> Bool:
    return path.startswith(separator)


def dirname(path: String) -> String:
    if not path:
        return "."
    var normalized = normalize(path)
    while normalized.byte_length() > 1 and normalized.endswith(separator):
        var trimmed = String(
            normalized[byte = 0 : normalized.byte_length() - 1]
        )
        normalized = trimmed^
    var index = normalized.rfind(separator)
    if index < 0:
        return "."
    if index == 0:
        return separator
    return String(normalized[byte=0:index])


def basename(path: String, suffix: String = "") -> String:
    if not path:
        return ""
    var normalized = normalize(path)
    while normalized.byte_length() > 1 and normalized.endswith(separator):
        var trimmed = String(
            normalized[byte = 0 : normalized.byte_length() - 1]
        )
        normalized = trimmed^
    var index = normalized.rfind(separator)
    var result = (
        String(normalized[byte = index + 1 : normalized.byte_length()]) if index
        >= 0 else normalized.copy()
    )
    if suffix and result.endswith(suffix) and result != suffix:
        return String(
            result[byte = 0 : result.byte_length() - suffix.byte_length()]
        )
    return result^


def extname(path: String) -> String:
    var base = basename(path)
    var index = base.rfind(".")
    if index <= 0:
        return ""
    return String(base[byte = index : base.byte_length()])


def parse(path: String) -> PathParts:
    var root = String(separator) if is_absolute(path) else String()
    var directory = dirname(path)
    if directory == "." and not root:
        directory = ""
    var base = basename(path)
    var extension = extname(base)
    var name = String(
        base[byte = 0 : base.byte_length() - extension.byte_length()]
    ) if extension else base.copy()
    return PathParts(root^, directory^, base^, name^, extension^)


def format_path(parts: PathParts) -> String:
    var base = parts.base if parts.base else parts.name + parts.extension
    if not parts.directory:
        return parts.root + base
    if parts.directory == separator:
        return separator + base
    return parts.directory + separator + base


def relative(from_path: String, to_path: String) raises -> String:
    var source_paths = List[String]()
    source_paths.append(from_path.copy())
    var target_paths = List[String]()
    target_paths.append(to_path.copy())
    var source = _components(resolve(from_path))
    var target = _components(resolve(to_path))
    var shared = 0
    while (
        shared < len(source)
        and shared < len(target)
        and source[shared] == target[shared]
    ):
        shared += 1

    var result = String()
    for _ in range(shared, len(source)):
        _append_component(result, "..")
    for index in range(shared, len(target)):
        _append_component(result, target[index])
    return result^ if result else String()
