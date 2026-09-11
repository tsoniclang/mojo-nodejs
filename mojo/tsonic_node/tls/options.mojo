from std.collections import List
from ..buffer import Buffer
from .secure_context import SecureContext, SecureContextOptions


struct ConnectionOptions(Copyable):
    var host: Optional[String]
    var servername: Optional[String]
    var port: Optional[Float64]
    var alpn_protocols: Optional[List[String]]
    var reject_unauthorized: Optional[Bool]
    var ca: Optional[List[String]]
    var timeout: Optional[Float64]
    var allow_half_open: Optional[Bool]
    var key: Optional[String]
    var cert: Optional[String]
    var pfx: Optional[Buffer]
    var passphrase: Optional[String]
    var min_version: Optional[String]
    var max_version: Optional[String]
    var secure_context: Optional[SecureContext]

    def __init__(
        out self,
        host: Optional[String] = None,
        servername: Optional[String] = None,
        port: Optional[Float64] = None,
        var alpn_protocols: Optional[List[String]] = None,
        reject_unauthorized: Optional[Bool] = None,
        var ca: Optional[List[String]] = None,
        timeout: Optional[Float64] = None,
        allow_half_open: Optional[Bool] = None,
        key: Optional[String] = None,
        cert: Optional[String] = None,
        pfx: Optional[Buffer] = None,
        passphrase: Optional[String] = None,
        min_version: Optional[String] = None,
        max_version: Optional[String] = None,
        secure_context: Optional[SecureContext] = None,
    ):
        self.host = host
        self.servername = servername
        self.port = port
        self.alpn_protocols = alpn_protocols^
        self.reject_unauthorized = reject_unauthorized
        self.ca = ca^
        self.timeout = timeout
        self.allow_half_open = allow_half_open
        self.key = key
        self.cert = cert
        self.pfx = pfx
        self.passphrase = passphrase
        self.min_version = min_version
        self.max_version = max_version
        self.secure_context = secure_context

    def context_options(self) -> SecureContextOptions:
        return SecureContextOptions(self.key, self.cert, self.ca.copy(), self.pfx,
            self.passphrase, self.min_version, self.max_version)


struct TlsOptions(Copyable):
    var key: Optional[String]
    var cert: Optional[String]
    var ca: Optional[List[String]]
    var alpn_protocols: Optional[List[String]]
    var request_cert: Optional[Bool]
    var reject_unauthorized: Optional[Bool]
    var allow_half_open: Optional[Bool]
    var handshake_timeout: Optional[Float64]
    var pfx: Optional[Buffer]
    var passphrase: Optional[String]
    var min_version: Optional[String]
    var max_version: Optional[String]

    def __init__(
        out self,
        key: Optional[String] = None,
        cert: Optional[String] = None,
        var ca: Optional[List[String]] = None,
        var alpn_protocols: Optional[List[String]] = None,
        request_cert: Optional[Bool] = None,
        reject_unauthorized: Optional[Bool] = None,
        allow_half_open: Optional[Bool] = None,
        handshake_timeout: Optional[Float64] = None,
        pfx: Optional[Buffer] = None,
        passphrase: Optional[String] = None,
        min_version: Optional[String] = None,
        max_version: Optional[String] = None,
    ):
        self.key = key
        self.cert = cert
        self.ca = ca^
        self.alpn_protocols = alpn_protocols^
        self.request_cert = request_cert
        self.reject_unauthorized = reject_unauthorized
        self.allow_half_open = allow_half_open
        self.handshake_timeout = handshake_timeout
        self.pfx = pfx
        self.passphrase = passphrase
        self.min_version = min_version
        self.max_version = max_version

    def context_options(self) -> SecureContextOptions:
        return SecureContextOptions(self.key, self.cert, self.ca.copy(), self.pfx,
            self.passphrase, self.min_version, self.max_version)
