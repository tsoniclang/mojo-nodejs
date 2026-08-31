from std.ffi import c_char, c_int, external_call
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
    elif CompilationTarget.is_arm():
        return "arm64" if bit_width_of[DType.int]() == 64 else "arm"
    elif CompilationTarget.is_rv64():
        return "riscv64"
    elif CompilationTarget.is_rv32():
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
