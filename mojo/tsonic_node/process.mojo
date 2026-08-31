from std.collections import List
from std.ffi import external_call
from std.os import chdir, setenv, unsetenv
from std.pathlib import Path, cwd
from std.sys import argv
from std.sys import exit as native_exit


def arguments() -> List[String]:
    var result = List[String](capacity=len(argv()))
    for argument in argv():
        result.append(String(argument))
    return result^


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


def current_directory() raises -> String:
    return String(cwd())


def change_directory(path: String) raises:
    chdir(Path(path))


def exit(code: Int = 0):
    native_exit(code)
