from std.ffi import c_int, external_call


def signal_number(name: String) raises -> Int:
    var selected = name.upper()
    if selected.find("\x00") >= 0:
        raise Error("Unknown signal: ", name)
    var number = external_call["tsonic_node_signal_number", c_int](
        selected.as_c_string_slice().ptr()
    )
    if number < 0:
        raise Error("Unknown signal: ", name)
    return Int(number)


def convert_process_signal_to_exit_code(signal: String) raises -> Float64:
    return Float64(128 + signal_number(signal))


def _int32(value: Float64, field: String) raises -> c_int:
    if not (value >= -2147483648.0 and value <= 2147483647.0):
        raise Error(field, " must be a signed 32-bit integer")
    var integer = c_int(value)
    if Float64(integer) != value:
        raise Error(field, " must be a signed 32-bit integer")
    return integer


def kill_default(pid: Float64) raises -> Bool:
    return kill_named(pid, "SIGTERM")


def kill_named(pid: Float64, signal: String) raises -> Bool:
    return _kill(_int32(pid, "pid"), c_int(signal_number(signal)))


def kill_number(pid: Float64, signal: Float64) raises -> Bool:
    return _kill(_int32(pid, "pid"), _int32(signal, "signal"))


def _kill(pid: c_int, signal: c_int) raises -> Bool:
    var status = external_call["uv_kill", c_int](pid, signal)
    if status != 0:
        raise Error("Unable to deliver process signal: ", String(status))
    return True
