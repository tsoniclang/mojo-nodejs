from std.collections import Array
from tsonic_js.uri import (
    decode_uri_component_native,
    encode_uri_component_native,
)
from .domain import domain_to_ascii


@fieldwise_init
struct LegacyUrl(Copyable):
    var href: Optional[String]
    var protocol: Optional[String]
    var slashes: Optional[Bool]
    var auth: Optional[String]
    var host: Optional[String]
    var port: Optional[String]
    var hostname: Optional[String]
    var hash: Optional[String]
    var search: Optional[String]
    var query: Optional[String]
    var pathname: Optional[String]
    var path: Optional[String]

    def __init__(out self):
        self.href = None
        self.protocol = None
        self.slashes = None
        self.auth = None
        self.host = None
        self.port = None
        self.hostname = None
        self.hash = None
        self.search = None
        self.query = None
        self.pathname = None
        self.path = None


def _slice(value: String, start: Int, end: Int) -> String:
    return String(value[byte=start:end])


def slashed_protocol(value: String) -> Bool:
    return value in (
        "http:",
        "https:",
        "ftp:",
        "gopher:",
        "file:",
        "ws:",
        "wss:",
    )


def _valid_scheme(value: String) -> Bool:
    if not value:
        return False
    for byte in value.as_bytes():
        if not (
            (byte >= 65 and byte <= 90)
            or (byte >= 97 and byte <= 122)
            or (byte >= 48 and byte <= 57)
            or byte == 43
            or byte == 45
            or byte == 46
        ):
            return False
    return True


def _trim_url(var input: String) -> String:
    var markers: Array[String, 2] = ["\u00a0", "\ufeff"]
    var changed = True
    while changed and input:
        changed = False
        for marker in markers:
            if input.startswith(marker):
                input = _slice(input, marker.byte_length(), input.byte_length())
                changed = True
            if input.endswith(marker):
                input = _slice(
                    input, 0, input.byte_length() - marker.byte_length()
                )
                changed = True
        var start = 0
        var end = input.byte_length()
        while start < end and UInt8(input.as_bytes()[start]) <= 32:
            start += 1
        while end > start and UInt8(input.as_bytes()[end - 1]) <= 32:
            end -= 1
        if start != 0 or end != input.byte_length():
            input = _slice(input, start, end)
            changed = True
    return input^


def _escape_url(input: String) -> String:
    comptime digits = "0123456789ABCDEF"
    var result = String()
    var start = 0
    for index in range(input.byte_length()):
        var byte = UInt8(input.as_bytes()[index])
        if (
            byte == 9
            or byte == 10
            or byte == 13
            or byte == 32
            or byte == 34
            or byte == 39
            or byte == 60
            or byte == 62
            or byte == 92
            or byte == 94
            or byte == 96
            or byte == 123
            or byte == 124
            or byte == 125
        ):
            result += _slice(input, start, index)
            result += (
                "%"
                + String(digits[byte=Int(byte >> 4)])
                + String(digits[byte=Int(byte & 15)])
            )
            start = index + 1
    result += _slice(input, start, input.byte_length())
    return result^


def _authority(mut result: LegacyUrl, var rest: String) raises -> String:
    rest = rest.replace("\t", "").replace("\n", "").replace("\r", "")
    var end = rest.byte_length()
    var delimiters: Array[String, 3] = ["/", "?", "#"]
    for delimiter in delimiters:
        var position = rest.find(delimiter)
        if position >= 0:
            end = min(end, position)
    var at = _slice(rest, 0, end).rfind("@")
    var start = 0
    if at >= 0:
        result.auth = decode_uri_component_native(_slice(rest, 0, at))
        start = at + 1
    for index in range(start, end):
        var byte = UInt8(rest.as_bytes()[index])
        if (
            byte == 32
            or byte == 34
            or byte == 37
            or byte == 39
            or byte == 59
            or byte == 60
            or byte == 62
            or byte == 92
            or byte == 94
            or byte == 96
            or byte == 123
            or byte == 124
            or byte == 125
        ):
            end = index
            break
    var host = _slice(rest, start, end)
    rest = _slice(rest, end, rest.byte_length())
    var port_at = host.rfind(":")
    if port_at >= 0:
        var port = _slice(host, port_at + 1, host.byte_length())
        var numeric = True
        for byte in port.as_bytes():
            if byte < 48 or byte > 57:
                numeric = False
        if numeric:
            host = _slice(host, 0, port_at)
            if port:
                result.port = port
    var ipv6 = host.startswith("[") and host.endswith("]")
    if not ipv6 and host.find(":") >= 0:
        raise Error("Invalid port in URL")
    host = host.lower()
    if host.byte_length() > 255 and not ipv6:
        host = ""
    elif host and not ipv6:
        host = domain_to_ascii(host)
        if not host:
            raise Error("Invalid URL hostname")
    result.host = host + (":" + result.port.value() if result.port else "")
    result.hostname = _slice(host, 1, host.byte_length() - 1) if ipv6 else host
    if ipv6 and not rest.startswith("/"):
        rest = "/" + rest
    return rest^


def parse_legacy(
    input: String, slashes_denote_host: Bool = False
) raises -> LegacyUrl:
    if input.find("\0") >= 0:
        raise Error("URL input contains a null character")
    var result = LegacyUrl()
    var rest = _trim_url(input)
    var split = rest.byte_length()
    var delimiters: Array[String, 2] = ["?", "#"]
    for delimiter in delimiters:
        var position = rest.find(delimiter)
        if position >= 0:
            split = min(split, position)
    rest = _slice(rest, 0, split).replace("\\", "/") + _slice(
        rest, split, rest.byte_length()
    )
    var colon = rest.find(":")
    var protocol = String()
    if colon > 0 and _valid_scheme(_slice(rest, 0, colon)):
        protocol = _slice(rest, 0, colon).lower() + ":"
        result.protocol = protocol
        rest = _slice(rest, colon + 1, rest.byte_length())
    var hostless = protocol == "javascript:"
    var double_slash = rest.startswith("//")
    var auth_authority = (
        double_slash and _slice(rest, 2, rest.byte_length()).find("@") >= 0
    )
    if (
        double_slash
        and (slashes_denote_host or protocol or auth_authority)
        and not hostless
    ):
        result.slashes = True
        rest = _slice(rest, 2, rest.byte_length())
    if not hostless and (
        (result.slashes and result.slashes.value())
        or (protocol and not slashed_protocol(protocol))
    ):
        rest = _authority(result, rest)
    if not hostless:
        rest = _escape_url(rest)
    var hash_at = rest.find("#")
    if hash_at >= 0:
        result.hash = _slice(rest, hash_at, rest.byte_length())
        rest = _slice(rest, 0, hash_at)
    var query_at = rest.find("?")
    if query_at >= 0:
        result.search = _slice(rest, query_at, rest.byte_length())
        result.query = _slice(rest, query_at + 1, rest.byte_length())
        rest = _slice(rest, 0, query_at)
    if rest:
        result.pathname = rest
    elif (
        slashed_protocol(protocol)
        and result.hostname
        and result.hostname.value()
    ):
        result.pathname = "/"
    if result.pathname or result.search:
        result.path = (result.pathname.value() if result.pathname else "") + (
            result.search.value() if result.search else ""
        )
    result.href = format_legacy(result)
    return result^


def format_legacy(value: LegacyUrl) raises -> String:
    var protocol = value.protocol.value() if value.protocol else String()
    if protocol and not protocol.endswith(":"):
        protocol += ":"
    var auth = String()
    if value.auth and value.auth.value():
        auth = (
            encode_uri_component_native(value.auth.value()).replace("%3A", ":")
            + "@"
        )
    var host = String()
    if value.host and value.host.value():
        host = auth + value.host.value()
    elif value.hostname and value.hostname.value():
        var hostname = value.hostname.value()
        if hostname.find(":") >= 0 and not (
            hostname.startswith("[") and hostname.endswith("]")
        ):
            hostname = "[" + hostname + "]"
        host = auth + hostname
        if value.port and value.port.value():
            host += ":" + value.port.value()
    var pathname = value.pathname.value() if value.pathname else String()
    pathname = pathname.replace("#", "%23").replace("?", "%3F")
    var search = value.search.value() if value.search else String()
    search = search.replace("#", "%23")
    if search and not search.startswith("?"):
        search = "?" + search
    var hash = value.hash.value() if value.hash else String()
    if hash and not hash.startswith("#"):
        hash = "#" + hash
    var slashes = value.slashes.value() if value.slashes else False
    if slashes or slashed_protocol(protocol):
        if slashes or host:
            if pathname and not pathname.startswith("/"):
                pathname = "/" + pathname
            host = "//" + host
        elif protocol == "file:":
            host = "//"
    return protocol + host + pathname + search + hash
