from std.collections import List
import std.os.path
from std.ffi import c_int, c_long, external_call
from std.io import FileDescriptor
from std.os import chdir, setenv, unsetenv
from std.pathlib import Path, cwd
from std.sys import CompilationTarget, argv
from std.sys import exit as native_exit
from std.time import monotonic
from tsonic_runtime import GlobalCell

from .buffer import Buffer
from .os_info import arch as os_arch
from .os_info import platform as os_platform


struct ProcessEnv(Copyable):
    def __init__(out self):
        pass

    def get(self, name: String) -> Optional[String]:
        return environment(name)


@fieldwise_init
struct MemoryUsage(Copyable):
    var rss: Float64
    var heap_total: Float64
    var heap_used: Float64
    var external: Float64
    var array_buffers: Float64


struct ProcessWriteStream(Copyable):
    var _fd: Int

    def __init__(out self, fd: Int):
        self._fd = fd

    def write_string(mut self, value: String) raises -> Bool:
        var descriptor = FileDescriptor(self._fd)
        descriptor.write_string(value)
        return True

    def write_buffer(mut self, value: Buffer) raises -> Bool:
        var descriptor = FileDescriptor(self._fd)
        var bytes = value.copy_bytes()
        descriptor.write_bytes(Span(bytes))
        return True

    def is_tty(self) -> Bool:
        return FileDescriptor(self._fd).isatty()

    def fd(self) -> Int:
        return self._fd


def _initial_exit_code() -> Optional[Int32]:
    return None


def _initial_start_time() -> Int:
    return monotonic()


comptime _exit_code = GlobalCell[
    "tsonic.node.process.exit_code", _initial_exit_code
]()
comptime _start_time = GlobalCell[
    "tsonic.node.process.start_time", _initial_start_time
]()


def environment_object() -> ProcessEnv:
    return ProcessEnv()


def environment(var name: String) -> Optional[String]:
    var value = external_call[
        "getenv", OptionalPointer[UInt8, ImmUntrackedOrigin]
    ](name.as_c_string_slice())
    if not value:
        return None
    return String(unsafe_from_utf8_ptr=value.value())


def set_environment(var name: String, var value: String) raises:
    if not setenv(name^, value^):
        raise Error("Unable to set environment variable")


def unset_environment(var name: String) raises:
    if not unsetenv(name^):
        raise Error("Unable to unset environment variable")


def arguments() raises -> List[String]:
    var native_arguments = argv()
    var executable = executable_path()
    var result = List[String](capacity=max(2, len(native_arguments) + 1))
    result.append(executable)
    result.append(executable)
    for index in range(1, len(native_arguments)):
        result.append(String(native_arguments[index]))
    return result^


def argument_zero() -> String:
    var values = argv()
    return String(values[0]) if len(values) else String()


def process_id() -> Int:
    return Int(external_call["getpid", c_int]())


def parent_process_id() -> Int:
    return Int(external_call["getppid", c_int]())


def executable_path() raises -> String:
    comptime if CompilationTarget.is_linux():
        return std.os.path.realpath(Path("/proc/self/exe"))
    else:
        var values = argv()
        if not len(values):
            raise Error("The executable path is unavailable")
        return std.os.path.realpath(Path(values[0]))


def platform() -> String:
    return os_platform()


def arch() -> String:
    return os_arch()


def current_directory() raises -> String:
    return String(cwd())


def change_directory(path: String) raises:
    chdir(Path(path))


def hrtime() -> List[Float64]:
    return _hrtime_pair(monotonic())


def hrtime_since(previous: List[Float64]) raises -> List[Float64]:
    if len(previous) != 2:
        raise Error(
            "The previous hrtime value must contain exactly two numbers"
        )
    var previous_ns = Int(previous[0] * 1_000_000_000.0 + previous[1])
    return _hrtime_pair(max(monotonic() - previous_ns, 0))


def _hrtime_pair(nanoseconds: Int) -> List[Float64]:
    var seconds = nanoseconds // 1_000_000_000
    var remainder = nanoseconds % 1_000_000_000
    var result = List[Float64](capacity=2)
    result.append(Float64(seconds))
    result.append(Float64(remainder))
    return result^


def uptime() -> Float64:
    return Float64(max(monotonic() - _start_time.get()[], 0)) / 1_000_000_000.0


def memory_usage() -> MemoryUsage:
    return MemoryUsage(_resident_set_size(), 0.0, 0.0, 0.0, 0.0)


def _resident_set_size() -> Float64:
    comptime if CompilationTarget.is_linux():
        try:
            var text = Path("/proc/self/statm").read_text()
            var fields = text.split(" ")
            if len(fields) < 2:
                return 0.0
            var pages = Int(String(fields[1]))
            var page_size = Int(external_call["sysconf", c_long](c_int(30)))
            return Float64(max(pages, 0) * max(page_size, 0))
        except:
            return 0.0
    else:
        return 0.0


def stdout() -> ProcessWriteStream:
    return ProcessWriteStream(1)


def stderr() -> ProcessWriteStream:
    return ProcessWriteStream(2)


def exit_code() -> Optional[Int32]:
    return _exit_code.get()[]


def set_exit_code(value: Optional[Int32]):
    _exit_code.get()[] = value


def apply_exit_code():
    var code = exit_code()
    if code:
        native_exit(Int(code.value()))


def exit_default():
    native_exit(0)


def exit(code: Int):
    native_exit(code)
