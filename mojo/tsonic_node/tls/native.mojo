from std.collections import List
from std.ffi import c_int, external_call
from ..validation import checked_integer


def _alpn_wire(protocols: Optional[List[String]]) raises -> List[Byte]:
    var output = List[Byte]()
    if not protocols:
        output.append(Byte(0))
        _ = output.pop()
        return output^
    for protocol in protocols.value():
        var length = protocol.byte_length()
        if length == 0 or length > 255:
            raise Error(
                "Each ALPN protocol must contain 1 through 255 UTF-8 bytes"
            )
        output.append(Byte(UInt8(length)))
        for byte in protocol.as_bytes():
            output.append(byte)
    return output^


def _join_certificates(certificates: Optional[List[String]]) raises -> String:
    if not certificates:
        return ""
    var result = String()
    for certificate in certificates.value():
        if certificate.find("\0") >= 0:
            raise Error("TLS authority contains a null byte")
        if result.byte_length() != 0:
            result += "\n"
        result += certificate
    return result^


def _port(value: Float64) raises -> Int32:
    return Int32(checked_integer(value, 65535, "TLS port"))


def _socket_readable(descriptor: Int32) raises -> Bool:
    var result = external_call["tsonic_node_socket_readable", c_int](descriptor)
    if result < 0:
        raise Error("Unable to poll TLS server socket")
    return result > 0


def _take_error(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin], fallback: String
) -> String:
    if not pointer:
        return fallback
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^
