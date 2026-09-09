from std.collections import List
from std.pathlib import cwd


comptime separator = "/"
comptime delimiter = ":"


struct PathParts(Copyable):
    var root: String
    var directory: String
    var base: String
    var name: String
    var extension: String

    def __init__(out self, var root: String = "", var directory: String = "", var base: String = "", var name: String = "", var extension: String = ""):
        self.root = root^
        self.directory = directory^
        self.base = base^
        self.name = name^
        self.extension = extension^


struct PathInput(Copyable):
    var root: Optional[String]
    var directory: Optional[String]
    var base: Optional[String]
    var name: Optional[String]
    var extension: Optional[String]

    def __init__(out self):
        self.root = None
        self.directory = None
        self.base = None
        self.name = None
        self.extension = None


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
    if trailing and result != separator:
        result += separator
    return result^


def join(parts: List[String]) -> String:
    if not len(parts):
        return "."
    var combined = String()
    for part in parts:
        if not part:
            continue
        _append_component(combined, part)
    return normalize(combined^)


def resolve(parts: List[String]) raises -> String:
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
    while normalized.byte_length() > 1 and normalized.endswith(separator):
        normalized = String(normalized[byte=:normalized.byte_length() - 1])
    if not normalized.startswith(separator):
        normalized = separator + normalized
    return normalized^


def is_absolute(path: String) -> Bool:
    return path.startswith(separator)


def dirname(path: String) -> String:
    if not path:
        return "."
    var end = _base_end(path)
    var index = String(path[byte=:end]).rfind(separator)
    if index < 0:
        return separator if path.startswith(separator) else "."
    if index == 0:
        return separator
    if index == 1 and path.startswith("//"):
        return "//"
    return String(path[byte=:index])


def _base_end(path: String) -> Int:
    var end = path.byte_length()
    var bytes = path.as_bytes()
    while end > 0 and bytes[end - 1] == 47:
        end -= 1
    return end


def basename(path: String, suffix: String = "") -> String:
    if not path:
        return ""
    if suffix and suffix == path:
        return ""
    var end = _base_end(path)
    var index = String(path[byte=:end]).rfind(separator)
    var result = String(path[byte=index + 1:end])
    if suffix and suffix.byte_length() <= path.byte_length() and suffix.endswith(result) and suffix != result:
        return String(path[byte=index + 1:])
    if suffix and result.endswith(suffix) and result != suffix:
        return String(
            result[byte = 0 : result.byte_length() - suffix.byte_length()]
        )
    return result^


def extname(path: String) -> String:
    var base = basename(path)
    var index = base.rfind(".")
    if index <= 0 or base == "..":
        return ""
    return String(base[byte = index : base.byte_length()])


def parse(path: String) -> PathParts:
    var root = String(separator) if is_absolute(path) else String()
    var end = _base_end(path)
    var start = String(path[byte=:end]).rfind(separator) + 1
    var directory = String(path[byte=:start - 1]) if start > 1 else root.copy()
    var base = basename(path)
    var extension = extname(base)
    var name = String(
        base[byte = 0 : base.byte_length() - extension.byte_length()]
    ) if extension else base.copy()
    return PathParts(root^, directory^, base^, name^, extension^)


def format_path(parts: PathParts) -> String:
    var extension = parts.extension
    if extension and not extension.startswith("."):
        extension = "." + extension
    var base = parts.base if parts.base else parts.name + extension
    var directory = parts.directory if parts.directory else parts.root
    if not directory:
        return base
    return directory + base if directory == parts.root else directory + separator + base


def format_path(parts: PathInput) -> String:
    return format_path(PathParts(
        parts.root.value() if parts.root else String(),
        parts.directory.value() if parts.directory else String(),
        parts.base.value() if parts.base else String(),
        parts.name.value() if parts.name else String(),
        parts.extension.value() if parts.extension else String(),
    ))


def relative(from_path: String, to_path: String) raises -> String:
    var source_paths = List[String]()
    source_paths.append(from_path.copy())
    var target_paths = List[String]()
    target_paths.append(to_path.copy())
    var source = _components(resolve(source_paths))
    var target = _components(resolve(target_paths))
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
