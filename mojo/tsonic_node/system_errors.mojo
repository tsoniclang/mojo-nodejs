from std.ffi import c_char, c_int, external_call


def _system_error(code: Float64, message: Bool) raises -> String:
    if not (code < 0 and code >= -2147483648.0):
        raise Error("A system error code must be a negative int32")
    var number = Int32(code)
    if Float64(number) != code:
        raise Error("A system error code must be an integer")
    var text = external_call[
        "tsonic_node_system_error", OptionalPointer[c_char, ImmUntrackedOrigin]
    ](c_int(number), c_int(message))
    if text:
        return String(unsafe_from_utf8_ptr=text.value())
    return "Unknown system error " + String(number)


def get_system_error_name(code: Float64) raises -> String:
    return _system_error(code, False)


def get_system_error_message(code: Float64) raises -> String:
    return _system_error(code, True)
