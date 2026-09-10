from std.collections import List
from std.utils import Variant
from ..buffer import Buffer
from ..url import URL
from ..validation import checked_integer

comptime Certificate = Variant[String, Buffer]
comptime Authorities = Variant[String, Buffer, List[String]]


struct RequestOptions(Copyable):
    var hostname: Optional[String]
    var path: Optional[String]
    var method: Optional[String]
    var protocol: Optional[String]
    var port: Optional[Float64]
    var timeout: Optional[Float64]
    var ca: Optional[Authorities]
    var cert: Optional[Certificate]
    var key: Optional[Certificate]
    var pfx: Optional[Buffer]
    var passphrase: Optional[String]
    var min_version: Optional[String]
    var max_version: Optional[String]
    var reject_unauthorized: Optional[Bool]

    def __init__(out self):
        self.hostname = None
        self.path = None
        self.method = None
        self.protocol = None
        self.port = None
        self.timeout = None
        self.ca = None
        self.cert = None
        self.key = None
        self.pfx = None
        self.passphrase = None
        self.min_version = None
        self.max_version = None
        self.reject_unauthorized = None


def request_url(options: RequestOptions, scheme: String) raises -> URL:
    var protocol = options.protocol.value() if options.protocol else scheme
    if protocol != scheme:
        raise Error("Request protocol does not match the selected Node module")
    var host = options.hostname.value() if options.hostname else String(
        "localhost"
    )
    if host.find(":") >= 0 and not host.startswith("["):
        host = "[" + host + "]"
    var address = URL(protocol + "//" + host)
    if options.port:
        address.set_port(
            String(checked_integer(options.port.value(), 65535, "request port"))
        )
    if options.path:
        var path = options.path.value()
        for byte in path.as_bytes():
            if byte <= 32 or byte == 127:
                raise Error(
                    "Request path contains an unescaped control character or"
                    " space"
                )
        var query = path.find("?")
        if query >= 0:
            address.set_pathname(String(path[byte=:query]))
            address.set_search(String(path[byte=query:]))
        else:
            address.set_pathname(path)
    return address


def certificate_bytes(value: Optional[Certificate]) -> Buffer:
    if not value:
        return Buffer()
    ref selected = value.value()
    if selected.isa[String]():
        return Buffer.from_string(selected.unsafe_get[String]())
    return selected.unsafe_get[Buffer]()


def authority_bytes(value: Optional[Authorities]) -> Buffer:
    if not value:
        return Buffer()
    ref selected = value.value()
    if selected.isa[String]():
        return Buffer.from_string(selected.unsafe_get[String]())
    if selected.isa[Buffer]():
        return selected.unsafe_get[Buffer]()
    var text = String()
    for authority in selected.unsafe_get[List[String]]():
        text += authority + "\n"
    return Buffer.from_string(text)


def tls_version(value: Optional[String]) raises -> Int32:
    if not value:
        return 0
    var name = value.value()
    if name == "TLSv1":
        return 1
    if name == "TLSv1.1":
        return 2
    if name == "TLSv1.2":
        return 3
    if name == "TLSv1.3":
        return 4
    raise Error("Unsupported TLS protocol version: ", name)


def check_token(value: String, role: String) raises:
    if not value:
        raise Error("HTTP ", role, " cannot be empty")
    for byte in value.as_bytes():
        if (
            (byte >= 65 and byte <= 90)
            or (byte >= 97 and byte <= 122)
            or (byte >= 48 and byte <= 57)
        ):
            continue
        if (
            byte == 33
            or byte == 35
            or byte == 36
            or byte == 37
            or byte == 38
            or byte == 39
            or byte == 42
            or byte == 43
            or byte == 45
            or byte == 46
            or byte == 94
            or byte == 95
            or byte == 96
            or byte == 124
            or byte == 126
        ):
            continue
        raise Error("HTTP ", role, " contains an invalid token character")
