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


def _slice(value: String, start: Int, end: Int) -> String:
    return String(value[byte=start:end])


def _valid_scheme(value: String) -> Bool:
    if not value:
        return False
    var bytes = value.as_bytes()
    var first = UInt8(bytes[0])
    if not (
        (first >= 0x41 and first <= 0x5A) or (first >= 0x61 and first <= 0x7A)
    ):
        return False
    for index in range(1, len(bytes)):
        var byte = UInt8(bytes[index])
        if not (
            (byte >= 0x41 and byte <= 0x5A)
            or (byte >= 0x61 and byte <= 0x7A)
            or (byte >= 0x30 and byte <= 0x39)
            or byte == 0x2B
            or byte == 0x2D
            or byte == 0x2E
        ):
            return False
    return True


def _split_host(authority: String) -> Tuple[String, Optional[String]]:
    if authority.startswith("["):
        var close = authority.find("]")
        if close >= 0:
            var hostname = _slice(authority, 0, close + 1)
            if (
                close + 1 < authority.byte_length()
                and _slice(authority, close + 1, close + 2) == ":"
            ):
                return (
                    hostname^,
                    Optional(
                        _slice(authority, close + 2, authority.byte_length())
                    ),
                )
            return (hostname^, None)
    var colon = authority.rfind(":")
    if colon < 0:
        return (authority, None)
    return (
        _slice(authority, 0, colon),
        Optional(_slice(authority, colon + 1, authority.byte_length())),
    )


def parse_legacy(input: String) raises -> LegacyUrl:
    if input.find("\0") >= 0:
        raise Error("URL input contains a null character")

    var before_hash = input.copy()
    var hash = Optional[String]()
    var hash_index = before_hash.find("#")
    if hash_index >= 0:
        hash = Optional(
            _slice(before_hash, hash_index, before_hash.byte_length())
        )
        before_hash = _slice(before_hash, 0, hash_index)

    var before_query = before_hash.copy()
    var search = Optional[String]()
    var query = Optional[String]()
    var query_index = before_query.find("?")
    if query_index >= 0:
        search = Optional(
            _slice(before_query, query_index, before_query.byte_length())
        )
        query = Optional(
            _slice(before_query, query_index + 1, before_query.byte_length())
        )
        before_query = _slice(before_query, 0, query_index)

    var protocol = Optional[String]()
    var remainder = before_query.copy()
    var colon = before_query.find(":")
    if colon > 0:
        var candidate = _slice(before_query, 0, colon)
        if _valid_scheme(candidate):
            protocol = Optional(candidate.lower() + ":")
            remainder = _slice(
                before_query, colon + 1, before_query.byte_length()
            )

    var slashes = Optional[Bool]()
    var auth = Optional[String]()
    var host = Optional[String]()
    var hostname = Optional[String]()
    var port = Optional[String]()
    var pathname = Optional[String]()
    if protocol and remainder.startswith("//"):
        slashes = Optional(True)
        var after_slashes = _slice(remainder, 2, remainder.byte_length())
        var slash = after_slashes.find("/")
        var authority = after_slashes.copy() if slash < 0 else _slice(
            after_slashes, 0, slash
        )
        pathname = Optional(
            String("/") if slash
            < 0 else _slice(after_slashes, slash, after_slashes.byte_length())
        )
        var at = authority.rfind("@")
        if at >= 0:
            auth = Optional(_slice(authority, 0, at))
            authority = _slice(authority, at + 1, authority.byte_length())
        host = Optional(authority.copy())
        var host_parts = _split_host(authority)
        hostname = Optional(host_parts[0])
        port = host_parts[1]
    elif remainder:
        pathname = Optional(remainder.copy())

    var path = Optional[String]()
    if pathname or search:
        var path_text = pathname.value() if pathname else String()
        if search:
            path_text += search.value()
        path = Optional(path_text^)

    return LegacyUrl(
        Optional(input.copy()),
        protocol^,
        slashes^,
        auth^,
        host^,
        port^,
        hostname^,
        hash^,
        search^,
        query^,
        pathname^,
        path^,
    )
