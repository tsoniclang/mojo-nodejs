from std.collections import List
from std.ffi import c_char, c_int, c_size_t, external_call
from std.memory import ArcPointer
from ..buffer import Buffer
from .native import _join_certificates, _take_error


struct SecureContextOptions(Copyable):
    var key: Optional[String]
    var cert: Optional[String]
    var ca: Optional[List[String]]
    var pfx: Optional[Buffer]
    var passphrase: Optional[String]
    var min_version: Optional[String]
    var max_version: Optional[String]

    def __init__(
        out self,
        key: Optional[String] = None,
        cert: Optional[String] = None,
        var ca: Optional[List[String]] = None,
        pfx: Optional[Buffer] = None,
        passphrase: Optional[String] = None,
        min_version: Optional[String] = None,
        max_version: Optional[String] = None,
    ):
        self.key = key
        self.cert = cert
        self.ca = ca^
        self.pfx = pfx
        self.passphrase = passphrase
        self.min_version = min_version
        self.max_version = max_version


struct _SecureContextState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle

    def __deinit__(deinit self):
        external_call["tsonic_node_tls_context_free", NoneType](self.handle)


struct SecureContext(ImplicitlyCopyable):
    var _state: ArcPointer[_SecureContextState]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self._state = ArcPointer(_SecureContextState(handle))


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


def create_secure_context(
    options: SecureContextOptions = SecureContextOptions(),
) raises -> SecureContext:
    var key = options.key.value() if options.key else String()
    var cert = options.cert.value() if options.cert else String()
    var password = (
        options.passphrase.value() if options.passphrase else String()
    )
    if key.find("\0") >= 0 or cert.find("\0") >= 0 or password.find("\0") >= 0:
        raise Error("TLS identity or passphrase contains a null byte")
    var ca = _join_certificates(options.ca)
    var pfx = options.pfx.value().copy_bytes() if options.pfx else List[Byte]()
    var key_pointer = OptionalPointer[c_char, ImmutAnyOrigin]()
    var cert_pointer = OptionalPointer[c_char, ImmutAnyOrigin]()
    if options.key:
        key_pointer = (
            key.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin()
        )
    if options.cert:
        cert_pointer = (
            cert.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin()
        )
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call[
        "tsonic_node_tls_context_create",
        OptionalPointer[NoneType, MutUntrackedOrigin],
    ](
        key_pointer,
        cert_pointer,
        ca.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin(),
        c_int(Bool(options.ca)),
        pfx.unsafe_ptr(),
        c_size_t(len(pfx)),
        c_int(Bool(options.pfx)),
        password.as_c_string_slice().unsafe_ptr().as_unsafe_any_origin(),
        tls_version(options.min_version),
        tls_version(options.max_version),
        Pointer(to=error),
    )
    if not handle:
        raise Error(_take_error(error, "Unable to configure TLS context"))
    return SecureContext(handle)
