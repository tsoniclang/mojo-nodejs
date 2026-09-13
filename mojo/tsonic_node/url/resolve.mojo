from std.collections import List
from .legacy import (
    LegacyUrl,
    parse_legacy,
    format_legacy,
    slashed_protocol,
    _slice,
)


def _text(value: Optional[String]) -> String:
    return value.value() if value else String()


def _path(value: Optional[String]) -> List[String]:
    var result = List[String]()
    if Bool(value) and Bool(value.value()):
        for component in value.value().split("/"):
            result.append(String(component))
    return result^


def _shift(mut path: List[String]) -> String:
    if not len(path):
        return ""
    var result = path[0].copy()
    var remainder = List[String](capacity=len(path) - 1)
    for index in range(1, len(path)):
        remainder.append(path[index])
    path = remainder^
    return result^


def _join(path: List[String]) -> String:
    var result = String()
    for index in range(len(path)):
        if index:
            result += "/"
        result += path[index]
    return result^


def _restore_opaque_host(
    mut result: LegacyUrl, mut path: List[String], absolute: Bool
):
    var host = String() if absolute else _shift(path)
    var at = host.find("@")
    if at > 0:
        result.auth = _slice(host, 0, at)
        host = _slice(host, at + 1, host.byte_length())
    result.host = host
    result.hostname = host


def _remove_dots(
    path: List[String], rooted: Bool, remove_all: Bool, trailing: Bool
) -> List[String]:
    var reverse = List[String](capacity=len(path))
    var parents = 0
    for index in range(len(path) - 1, -1, -1):
        if path[index] == ".":
            continue
        if path[index] == "..":
            parents += 1
        elif parents:
            parents -= 1
        else:
            reverse.append(path[index])
    if not rooted and not remove_all:
        for unused in range(parents):
            reverse.append("..")
    var result = List[String](capacity=len(reverse) + 2)
    if rooted and (not len(reverse) or reverse[len(reverse) - 1] != ""):
        result.append("")
    for index in range(len(reverse) - 1, -1, -1):
        result.append(reverse[index])
    if trailing and not _join(result).endswith("/"):
        result.append("")
    return result^


def resolve(from_url: String, to_url: String) raises -> String:
    var result = parse_legacy(from_url, True)
    var relative = parse_legacy(to_url, True)
    result.hash = relative.hash
    if not _text(relative.href):
        return format_legacy(result)
    if (
        Bool(relative.slashes)
        and relative.slashes.value()
        and not relative.protocol
    ):
        relative.protocol = result.protocol
        if (
            slashed_protocol(_text(relative.protocol))
            and _text(relative.hostname)
            and not _text(relative.pathname)
        ):
            relative.pathname = "/"
        return format_legacy(relative)
    if Bool(relative.protocol) and _text(relative.protocol) != _text(
        result.protocol
    ):
        if not slashed_protocol(relative.protocol.value()):
            return format_legacy(relative)
        result.protocol = relative.protocol
        if not _text(relative.host) and relative.protocol.value() != "file:":
            var path = _path(relative.pathname)
            var host = String()
            while len(path) and not host:
                host = _shift(path)
            relative.host = host
            if not len(path) or path[0] != "":
                path.insert(0, "")
            if len(path) < 2:
                path.insert(0, "")
            result.pathname = _join(path)
        else:
            result.pathname = relative.pathname
        result.search = relative.search
        result.host = _text(relative.host)
        result.auth = relative.auth
        result.hostname = _text(relative.hostname) if _text(
            relative.hostname
        ) else _text(relative.host)
        result.port = relative.port
        result.slashes = (Bool(result.slashes) and result.slashes.value()) or (
            Bool(relative.slashes) and relative.slashes.value()
        )
        return format_legacy(result)
    var relative_absolute = Bool(_text(relative.host)) or _text(
        relative.pathname
    ).startswith("/")
    var rooted = (
        relative_absolute
        or _text(result.pathname).startswith("/")
        or (Bool(_text(result.host)) and Bool(_text(relative.pathname)))
    )
    var remove_all = rooted
    var source_path = _path(result.pathname)
    var relative_path = _path(relative.pathname)
    var opaque = Bool(result.protocol) and not slashed_protocol(
        _text(result.protocol)
    )
    if opaque:
        result.hostname = ""
        result.port = None
        if _text(result.host):
            if len(source_path) and source_path[0] == "":
                source_path[0] = result.host.value()
            else:
                source_path.insert(0, result.host.value())
        result.host = ""
        if relative.protocol:
            relative.hostname = None
            relative.port = None
            result.auth = None
            if _text(relative.host):
                if len(relative_path) and relative_path[0] == "":
                    relative_path[0] = relative.host.value()
                else:
                    relative_path.insert(0, relative.host.value())
            relative.host = None
        rooted = rooted and (
            (len(relative_path) != 0 and relative_path[0] == "")
            or (len(source_path) != 0 and source_path[0] == "")
        )
    if relative_absolute:
        if relative.host:
            if _text(result.host) != relative.host.value():
                result.auth = None
            result.host = relative.host
            result.port = relative.port
        if relative.hostname:
            if _text(result.hostname) != relative.hostname.value():
                result.auth = None
            result.hostname = relative.hostname
        result.search = relative.search
        source_path = relative_path.copy()
    elif len(relative_path):
        if len(source_path):
            _ = source_path.pop()
        for component in relative_path:
            source_path.append(component)
        result.search = relative.search
    elif relative.search:
        if opaque:
            _restore_opaque_host(result, source_path, False)
        result.search = relative.search
        return format_legacy(result)
    if not len(source_path):
        result.pathname = None
        return format_legacy(result)
    var last = source_path[len(source_path) - 1]
    var trailing = last == "" or (
        (
            Bool(_text(result.host))
            or Bool(_text(relative.host))
            or len(source_path) > 1
        )
        and (last == "." or last == "..")
    )
    source_path = _remove_dots(source_path, rooted, remove_all, trailing)
    var absolute = len(source_path) != 0 and source_path[0] == ""
    if opaque:
        _restore_opaque_host(result, source_path, absolute)
    rooted = rooted or (Bool(_text(result.host)) and len(source_path) != 0)
    if rooted and not absolute:
        source_path.insert(0, "")
    result.pathname = Optional(_join(source_path)) if len(
        source_path
    ) else Optional[String]()
    if _text(relative.auth):
        result.auth = relative.auth
    result.slashes = (Bool(result.slashes) and result.slashes.value()) or (
        Bool(relative.slashes) and relative.slashes.value()
    )
    return format_legacy(result)
