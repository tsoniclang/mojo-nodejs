from std.collections import List
from std.ffi import c_char, c_int, external_call, get_errno
from std.pathlib import Path
from std.sys import CompilationTarget, bit_width_of
from std.tempfile import gettempdir


def temp_directory() raises -> String:
    var result = gettempdir()
    if not result:
        raise Error("Unable to determine the temporary directory")
    return result.value()


def home_directory() raises -> String:
    return String(Path.home())


def platform() -> String:
    comptime if CompilationTarget.is_linux():
        return "linux"
    elif CompilationTarget.is_macos():
        return "darwin"
    else:
        return "unknown"


def arch() -> String:
    comptime if CompilationTarget.is_x86():
        return "x64" if bit_width_of[DType.int]() == 64 else "ia32"
    elif CompilationTarget._is_arch["arm"]() or CompilationTarget._is_arch[
        "aarch64"
    ]():
        return "arm64" if bit_width_of[DType.int]() == 64 else "arm"
    elif CompilationTarget._is_arch["riscv64"]():
        return "riscv64"
    elif CompilationTarget._is_arch["riscv32"]():
        return "riscv32"
    else:
        return "unknown"


def end_of_line() -> String:
    return "\n"


def host_name() raises -> String:
    comptime buffer_size = 256
    var buffer = Array[c_char, buffer_size](uninitialized=True)
    var status = external_call["gethostname", c_int](
        buffer.unsafe_ptr(), buffer_size
    )
    if status != 0:
        raise Error("Unable to determine host name")
    return String(unsafe_from_utf8_ptr=buffer.unsafe_ptr())


def available_parallelism() -> Float64:
    return Float64(external_call["uv_available_parallelism", UInt32]())


def free_memory() -> Float64:
    return Float64(external_call["uv_get_free_memory", UInt64]())


def total_memory() -> Float64:
    return Float64(external_call["uv_get_total_memory", UInt64]())


def load_average() -> List[Float64]:
    var values: Array[Float64, 3] = [0.0, 0.0, 0.0]
    external_call["uv_loadavg", NoneType](values.unsafe_ptr())
    var result = List[Float64](capacity=3)
    for index in range(3):
        result.append(values[index])
    return result^


def uptime() raises -> Float64:
    var seconds = Float64(0)
    var status = external_call["uv_uptime", c_int](Pointer(to=seconds))
    if status != 0:
        raise Error("Unable to determine system uptime: ", status)
    return seconds


def endianness() -> String:
    return "LE" if external_call[
        "tsonic_node_os_little_endian", c_int
    ]() else "BE"


def _system_name(field: Int32) raises -> String:
    var result = external_call[
        "tsonic_node_os_name", OptionalPointer[c_char, MutUntrackedOrigin]
    ](c_int(field))
    if not result:
        raise Error("Unable to determine system name: ", get_errno())
    try:
        return String(unsafe_from_utf8_ptr=result.value())
    finally:
        external_call["free", NoneType](result.value())


def system_type() raises -> String:
    return _system_name(0)


def release() raises -> String:
    return _system_name(1)


def version() raises -> String:
    return _system_name(2)


def machine() raises -> String:
    return _system_name(3)


def dev_null() -> String:
    return "/dev/null"
