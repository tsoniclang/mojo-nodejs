from tsonic_js.uri import encode_uri_component_native
from .legacy import LegacyUrl, parse_legacy
from .url import URL


def format_url(value: LegacyUrl) raises -> String:
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
    var slashed_protocol = (
        protocol == "http:"
        or protocol == "https:"
        or protocol == "ftp:"
        or protocol == "gopher:"
        or protocol == "file:"
        or protocol == "ws:"
        or protocol == "wss:"
    )
    if slashes or slashed_protocol:
        if slashes or host:
            if pathname and not pathname.startswith("/"):
                pathname = "/" + pathname
            host = "//" + host
        elif protocol == "file:":
            host = "//"
    return protocol + host + pathname + search + hash


def format_url(value: URL) raises -> String:
    return value.href()


def format_url(value: String) raises -> String:
    return format_url(parse_legacy(value))
