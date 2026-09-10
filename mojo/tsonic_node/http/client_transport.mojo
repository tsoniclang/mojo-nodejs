from std.collections import List
from std.ffi import c_int, c_size_t, c_long, external_call
from std.memory import ArcPointer
from ..buffer import Buffer
from ..validation import checked_integer
from .client_options import RequestOptions, authority_bytes, certificate_bytes, tls_version

comptime MAX_MESSAGE_BYTES = 268_435_456


struct _NativeRequestState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_http_free", NoneType](self.handle.value())


struct NativeRequest(ImplicitlyCopyable):
    var _state: ArcPointer[_NativeRequestState]

    def __init__(out self, url: String, options: RequestOptions) raises:
        var handle = external_call["tsonic_node_http_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
            url.as_c_string_slice(), c_size_t(MAX_MESSAGE_BYTES),
        )
        if not handle:
            raise Error("Unable to allocate HTTP transport")
        self._state = ArcPointer(_NativeRequestState(handle))
        var ca = authority_bytes(options.ca).copy_bytes()
        var cert = certificate_bytes(options.cert).copy_bytes()
        var key = certificate_bytes(options.key).copy_bytes()
        var pfx = options.pfx.value().copy_bytes() if options.pfx else List[Byte]()
        var password = options.passphrase.value() if options.passphrase else String()
        if password.find("\0") >= 0:
            raise Error("TLS passphrase contains a null byte")
        var minimum = tls_version(options.min_version)
        var maximum = tls_version(options.max_version)
        if minimum != 0 and maximum != 0 and minimum > maximum:
            raise Error("Minimum TLS version exceeds maximum TLS version")
        if external_call["tsonic_node_http_tls", c_int](
            handle.value(), c_int(options.reject_unauthorized.value() if options.reject_unauthorized else True), minimum, maximum,
            ca.unsafe_ptr(), c_size_t(len(ca)), cert.unsafe_ptr(), c_size_t(len(cert)),
            key.unsafe_ptr(), c_size_t(len(key)), pfx.unsafe_ptr(), c_size_t(len(pfx)), password.as_c_string_slice(),
        ) == 0:
            self.check_error()
            raise Error("Unable to configure HTTP TLS transport")

    def close(self):
        if self._state[].handle:
            var handle = self._state[].handle.value()
            self._state[].handle = None
            external_call["tsonic_node_http_free", NoneType](handle)

    def complete(self) -> Bool:
        return Bool(self._state[].handle) and external_call["tsonic_node_http_complete", c_int](self._state[].handle.value()) != 0

    def check_error(self) raises:
        var message = external_call["tsonic_node_http_error", OptionalPointer[UInt8, ImmUntrackedOrigin]](self._state[].handle.value())
        if message:
            raise Error(String(unsafe_from_utf8_ptr=message.value()))

    def header(self, name: String, value: String) raises:
        var line = name + ": " + value if value else name + ";"
        if external_call["tsonic_node_http_header", c_int](self._state[].handle.value(), line.as_c_string_slice()) == 0:
            raise Error("Unable to add HTTP request header")

    def start(self, method: String, body: List[Byte], present: Bool, timeout: Optional[Float64]) raises:
        var delay = c_long(checked_integer(timeout.value(), 2147483647, "request timeout")) if timeout else c_long(0)
        if external_call["tsonic_node_http_start", c_int](
            self._state[].handle.value(), method.as_c_string_slice(), body.unsafe_ptr(),
            c_size_t(len(body)), c_int(present), delay,
        ) == 0:
            self.check_error()
            raise Error("Unable to start HTTP request")

    def status(self) -> Int32:
        return Int32(external_call["tsonic_node_http_status", c_int](self._state[].handle.value()))

    def body(self) -> Buffer:
        var length = c_size_t(0)
        var pointer = external_call["tsonic_node_http_body", OptionalPointer[Byte, ImmUntrackedOrigin]](
            self._state[].handle.value(), Pointer(to=length),
        )
        var bytes = List[Byte](capacity=Int(length))
        for index in range(Int(length)):
            bytes.append(pointer.value()[index])
        return Buffer(bytes^)


def poll_transport() raises:
    if external_call["tsonic_node_http_poll", c_int]() < 0:
        raise Error("HTTP multi-request transport failed")
