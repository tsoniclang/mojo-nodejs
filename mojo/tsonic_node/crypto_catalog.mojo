from std.collections import List
from std.ffi import c_char, c_int, c_size_t, external_call, get_errno


def _names(kind: Int32) raises -> List[String]:
    var names = external_call["tsonic_node_crypto_names", OptionalPointer[NoneType, MutUntrackedOrigin]](c_int(kind))
    if not names:
        raise Error("Unable to enumerate cryptographic algorithms: ", get_errno())
    try:
        var size = Int(external_call["tsonic_node_crypto_names_size", c_size_t](names.value()))
        var result = List[String](capacity=size)
        for index in range(size):
            var name = external_call["tsonic_node_crypto_name_at", OptionalPointer[c_char, ImmutUntrackedOrigin]](names.value(), c_size_t(index))
            if not name:
                raise Error("Cryptographic algorithm inventory changed during enumeration")
            result.append(String(unsafe_from_utf8_ptr=name.value()))
        return result^
    finally:
        external_call["tsonic_node_crypto_names_free", NoneType](names.value())


def get_ciphers() raises -> List[String]:
    return _names(0)


def get_hashes() raises -> List[String]:
    return _names(1)


def get_curves() raises -> List[String]:
    return _names(2)
