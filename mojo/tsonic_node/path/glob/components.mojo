from std.collections import List
from .limits import require_expansion_size, require_source_size


def split_components(path: String, windows: Bool) -> List[String]:
    var components = List[String]()
    var start = 0
    var bytes = path.as_bytes()
    var index = 0
    if windows and path.startswith("//") and len(bytes) > 2 and bytes[2] != 47:
        components.append("")
    while index < len(bytes):
        if bytes[index] == 47:
            components.append(String(path[byte=start:index]))
            while index + 1 < len(bytes) and bytes[index + 1] == 47:
                index += 1
            start = index + 1
        index += 1
    components.append(String(path[byte=start:]))
    return components^


def normalize_components(parts: List[String], pattern: Bool) -> List[String]:
    var result = List[String]()
    for index in range(len(parts)):
        var part = parts[index]
        if index > 0 and index + 1 < len(parts) and (part == "." or not part):
            if not (index == 1 and not part and not parts[0]):
                continue
        if pattern and part == "**" and len(result) and result[len(result) - 1] == "**":
            continue
        if part == ".." and len(result):
            var previous = result[len(result) - 1]
            if previous and previous != "." and previous != ".." and previous != "**":
                _ = result.pop()
                if pattern and not len(result) and index + 1 < len(parts) and parts[index + 1] == "**":
                    result.append(".")
                continue
        result.append(part)
    if len(result) == 2 and result[0] == "." and (result[1] == "." or not result[1]):
        _ = result.pop()
    if not len(result):
        result.append("")
    return result^


def pattern_components(pattern: String, windows: Bool) raises -> List[List[String]]:
    var pending = List[List[String]]()
    pending.append(normalize_components(split_components(pattern, windows), True))
    var output = List[List[String]]()
    var size = 0
    while len(pending):
        var parts = pending.pop()
        var split = False
        for index in range(len(parts) - 3):
            if parts[index] != "**" or parts[index + 1] != "..":
                continue
            var first = parts[index + 2]
            var second = parts[index + 3]
            if not first or first == "." or first == ".." or not second or second == "." or second == "..":
                continue
            var parent = List[String]()
            var recursive = List[String]()
            for part_index in range(len(parts)):
                if part_index != index:
                    parent.append(parts[part_index])
                if part_index != index + 1:
                    recursive.append(parts[part_index])
            pending.append(normalize_components(parent^, True))
            pending.append(normalize_components(recursive^, True))
            require_expansion_size(len(pending) + len(output))
            split = True
            break
        if not split:
            for part in parts:
                size += part.byte_length()
            require_source_size(size)
            output.append(parts^)
    return output^


def is_drive(part: String) -> Bool:
    if part.byte_length() != 2 or part.as_bytes()[1] != 58:
        return False
    var letter = part.as_bytes()[0]
    return 65 <= letter <= 90 or 97 <= letter <= 122


def strip_drive_namespace(mut parts: List[String]):
    if len(parts) >= 4 and not parts[0] and not parts[1] and parts[2] == "?" and is_drive(parts[3]):
        var output = List[String]()
        for index in range(3, len(parts)):
            output.append(parts[index])
        parts = output^
