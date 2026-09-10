from std.collections import List
from std.pathlib import cwd
from ..process import environment
from .model import PathParts, PathInput
from .roots import windows_root, is_drive, is_separator
from . import posix

comptime separator = "\\"
comptime delimiter = ";"


def _parts(path: String, allow_parent: Bool) -> List[String]:
    var result = List[String]()
    var slashes = path.replace("\\", "/")
    for part in slashes.split("/"):
        var value = String(part)
        if not value or value == ".":
            continue
        if value == "..":
            if len(result) != 0 and result[len(result) - 1] != "..":
                _ = result.pop()
            elif allow_parent:
                result.append(value^)
        else:
            result.append(value^)
    return result^


def _join(parts: List[String]) -> String:
    var output = String()
    for part in parts:
        if output:
            output += separator
        output += part
    return output^


def normalize(path: String) -> String:
    if not path:
        return "."
    if path.byte_length() == 1:
        return separator if path == "/" else path
    var root = windows_root(path, True)
    var tail = _join(_parts(String(path[byte=root.tail_start:]), not root.absolute))
    if not tail and not root.absolute:
        tail = "."
    if tail and is_separator(path.as_bytes()[path.byte_length() - 1]):
        tail += separator
    var prefix = root.device + (separator if root.absolute else String())
    if root.reserved:
        prefix = ".\\" + prefix
    if not root.absolute and not root.device and path.find(":") >= 0:
        var bytes = tail.as_bytes()
        var guarded = len(bytes) >= 2 and is_drive(bytes[0]) and bytes[1] == 58
        var original = path.as_bytes()
        for index in range(len(original)):
            if original[index] == 58 and (index + 1 == len(original) or is_separator(original[index + 1])):
                guarded = True
        if guarded:
            prefix = ".\\"
    return prefix + tail


def is_absolute(path: String) -> Bool:
    return windows_root(path).absolute


def join(parts: List[String]) -> String:
    var combined = String()
    var allow_unc = False
    for part in parts:
        if not part:
            continue
        if not combined:
            combined = part
            var bytes = part.as_bytes()
            allow_unc = len(bytes) > 2 and is_separator(bytes[0]) and is_separator(bytes[1]) and not is_separator(bytes[2])
        else:
            combined += separator + part
    if not allow_unc and combined:
        var offset = 0
        var bytes = combined.as_bytes()
        while offset < len(bytes) and is_separator(bytes[offset]):
            offset += 1
        if offset > 1:
            combined = separator + String(combined[byte=offset:])
    return normalize(combined)


def _resolve(parts: List[String], current: Optional[String], drive_current: Optional[String]) raises -> String:
    var device = String()
    var tail = String()
    var absolute = False
    var index = len(parts) - 1
    while index >= -1:
        var part = String()
        if index >= 0:
            part = parts[index]
        else:
            part = current.value() if current else String(cwd())
        if index == -1 and device:
            var selected_current = drive_current if current else environment("=" + device)
            if selected_current and selected_current.value():
                part = selected_current.value()
            var bytes = part.as_bytes()
            if len(bytes) >= 3 and bytes[2] == 92 and String(part[byte=:2]).lower() != device.lower():
                part = device + separator
        index -= 1
        if not part:
            continue
        var root = windows_root(part, True)
        if root.device:
            if device and device.lower() != root.device.lower():
                continue
            device = root.device if not device else device
        if not absolute:
            tail = String(part[byte=root.tail_start:]) + separator + tail
            absolute = root.absolute
        if absolute and device:
            break
    var result = device + (separator if absolute else String()) + _join(_parts(tail, not absolute))
    return result^ if result else String(".")


def resolve_with_cwd(parts: List[String], current: String, drive_current: Optional[String] = None) raises -> String:
    return _resolve(parts, current, drive_current)


def resolve(parts: List[String]) raises -> String:
    return _resolve(parts, None, None)


def basename(path: String, suffix: String = "") -> String:
    if suffix and suffix == path:
        return ""
    var bytes = path.as_bytes()
    var start = 2 if len(bytes) >= 2 and is_drive(bytes[0]) and bytes[1] == 58 else 0
    return posix.basename(String(path[byte=start:]).replace("\\", "/"), suffix)


def extname(path: String) -> String:
    return posix.extname(basename(path))


def dirname(path: String) -> String:
    if not path:
        return "."
    var root = windows_root(path)
    var end = path.byte_length()
    var bytes = path.as_bytes()
    while end > root.display_end and is_separator(bytes[end - 1]):
        end -= 1
    if end == root.display_end:
        return String(path[byte=:root.display_end])
    var start = end
    while start > root.display_end and not is_separator(bytes[start - 1]):
        start -= 1
    if start <= root.display_end:
        return String(path[byte=:root.display_end]) if root.display_end else String(".")
    return String(path[byte=:start - 1])


def parse(path: String) -> PathParts:
    var root = windows_root(path)
    var end = path.byte_length()
    var bytes = path.as_bytes()
    while end > root.display_end and is_separator(bytes[end - 1]):
        end -= 1
    var start = end
    while start > root.display_end and not is_separator(bytes[start - 1]):
        start -= 1
    var root_text = String(path[byte=:root.display_end])
    var directory = String(path[byte=:start - 1]) if start > root.display_end else root_text.copy()
    var base = String(path[byte=start:end])
    var extension = posix.extname(base)
    var name = String(base[byte=:base.byte_length() - extension.byte_length()])
    return PathParts(root_text^, directory^, base^, name^, extension^)


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
    var source_parts = List[String]()
    source_parts.append(from_path)
    var target_parts = List[String]()
    target_parts.append(to_path)
    var source = resolve(source_parts)
    var target = resolve(target_parts)
    var source_root = windows_root(source)
    var target_root = windows_root(target)
    if source_root.device.lower() != target_root.device.lower():
        return target^
    var source_tail = _parts(String(source[byte=source_root.tail_start:]), False)
    var target_tail = _parts(String(target[byte=target_root.tail_start:]), False)
    var shared = 0
    while shared < len(source_tail) and shared < len(target_tail) and source_tail[shared].lower() == target_tail[shared].lower():
        shared += 1
    var result = List[String]()
    for _ in range(shared, len(source_tail)):
        result.append("..")
    for index in range(shared, len(target_tail)):
        result.append(target_tail[index])
    return _join(result)


def to_namespaced_path(path: String) raises -> String:
    if not path:
        return path
    var parts = List[String]()
    parts.append(path)
    var result = resolve(parts)
    var bytes = result.as_bytes()
    if len(bytes) <= 2:
        return path
    if result.startswith("\\\\") and bytes[2] != 63 and bytes[2] != 46:
        return "\\\\?\\UNC\\" + String(result[byte=2:])
    if len(bytes) >= 3 and is_drive(bytes[0]) and bytes[1] == 58 and bytes[2] == 92:
        return "\\\\?\\" + result
    return result^
