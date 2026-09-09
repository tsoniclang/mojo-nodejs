from std.collections import List


struct ConnectionOptions(Copyable):
    var host: Optional[String]
    var servername: Optional[String]
    var port: Optional[Float64]
    var alpn_protocols: Optional[List[String]]
    var reject_unauthorized: Optional[Bool]
    var ca: Optional[List[String]]
    var timeout: Optional[Float64]
    var allow_half_open: Optional[Bool]

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
    ):
        self.host = host
        self.servername = servername
        self.port = port
        self.alpn_protocols = alpn_protocols^
        self.reject_unauthorized = reject_unauthorized
        self.ca = ca^
        self.timeout = timeout
        self.allow_half_open = allow_half_open


struct TlsOptions(Copyable):
    var key: Optional[String]
    var cert: Optional[String]
    var ca: Optional[List[String]]
    var alpn_protocols: Optional[List[String]]
    var request_cert: Optional[Bool]
    var reject_unauthorized: Optional[Bool]
    var allow_half_open: Optional[Bool]
    var handshake_timeout: Optional[Float64]

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
    ):
        self.key = key
        self.cert = cert
        self.ca = ca^
        self.alpn_protocols = alpn_protocols^
        self.request_cert = request_cert
        self.reject_unauthorized = reject_unauthorized
        self.allow_half_open = allow_half_open
        self.handshake_timeout = handshake_timeout
