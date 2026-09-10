from std.math import isfinite


def timeout_duration(value: Float64) raises -> Float64:
    if not isfinite(value) or value < 0:
        raise Error("Socket timeout must be a non-negative finite number")
    return min(value, 2147483647.0)


struct ServerOptions(Copyable):
    var allow_half_open: Optional[Bool]
    var pause_on_connect: Optional[Bool]

    def __init__(
        out self,
        allow_half_open: Optional[Bool] = None,
        pause_on_connect: Optional[Bool] = None,
    ):
        self.allow_half_open = allow_half_open
        self.pause_on_connect = pause_on_connect


struct ConnectionOptions(Copyable):
    var port: Float64
    var host: Optional[String]
    var allow_half_open: Optional[Bool]
    var no_delay: Optional[Bool]
    var timeout: Optional[Float64]

    def __init__(
        out self,
        port: Float64,
        host: Optional[String] = None,
        allow_half_open: Optional[Bool] = None,
        no_delay: Optional[Bool] = None,
        timeout: Optional[Float64] = None,
    ):
        self.port = port
        self.host = host
        self.allow_half_open = allow_half_open
        self.no_delay = no_delay
        self.timeout = timeout
