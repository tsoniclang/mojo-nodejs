from std.collections import Span
from std.ffi import c_char, c_int, c_size_t, external_call, get_errno


def _domain(input: String, unicode: Bool) raises -> String:
    var length = c_size_t(0)
    var output = external_call["tsonic_node_url_domain", OptionalPointer[c_char, MutUntrackedOrigin]](
        input.as_bytes().unsafe_ptr(), c_size_t(input.byte_length()), c_int(unicode), Pointer(to=length),
    )
    if not output:
        raise Error("Unable to convert domain: ", get_errno())
    try:
        return String(unsafe_from_utf8=Span(unsafe_ptr=output.value().unsafe_bitcast[Byte](), length=Int(length)))
    finally:
        external_call["tsonic_node_url_domain_free", NoneType](output.value())


def domain_to_ascii(input: String) raises -> String:
    return _domain(input, False)


def domain_to_unicode(input: String) raises -> String:
    return _domain(input, True)
