import std.os.path
from std.collections import List
from std.ffi import c_int, external_call, get_errno
from std.os import (
    makedirs,
    mkdir,
    remove,
    rmdir,
    symlink,
)
from std.pathlib import Path

from ..buffer import Buffer
from .metadata import Stats, stat, lstat
from .validation import checked_integer, checked_path, check_status


struct MkdirOptions(Copyable):
    var recursive: Optional[Bool]
    var mode: Optional[Float64]

    def __init__(
        out self,
        recursive: Optional[Bool] = None,
        mode: Optional[Float64] = None,
    ):
        self.recursive = recursive
        self.mode = mode


struct RmOptions(Copyable):
    var recursive: Optional[Bool]
    var force: Optional[Bool]
    var max_retries: Optional[Float64]
    var retry_delay: Optional[Float64]

    def __init__(
        out self,
        recursive: Optional[Bool] = None,
        force: Optional[Bool] = None,
        max_retries: Optional[Float64] = None,
        retry_delay: Optional[Float64] = None,
    ):
        self.recursive = recursive
        self.force = force
        self.max_retries = max_retries
        self.retry_delay = retry_delay


struct ReaddirOptions(Copyable):
    var with_file_types: Bool

    def __init__(out self, with_file_types: Bool = True):
        self.with_file_types = with_file_types


@fieldwise_init
struct Dirent(Copyable):
    var name: String
    var _file: Bool
    var _directory: Bool
    var _symbolic_link: Bool

    def is_file(self) -> Bool:
        return self._file

    def is_directory(self) -> Bool:
        return self._directory

    def is_symbolic_link(self) -> Bool:
        return self._symbolic_link


def exists(path: String) -> Bool:
    return std.os.path.exists(Path(path))


def read_file(path: String) raises -> Buffer:
    return Buffer(Path(path).read_bytes())


def read_text_file(path: String) raises -> String:
    return Path(path).read_text()


def read_text_file_encoded(path: String, encoding: String) raises -> String:
    if encoding != "utf8":
        raise Error("Only the exact 'utf8' text encoding is supported")
    return read_text_file(path)


def write_file(path: String, buffer: Buffer) raises:
    var bytes = buffer.copy_bytes()
    Path(path).write_bytes(Span(bytes))


def write_text_file(path: String, value: String) raises:
    Path(path).write_text(value)


def append_file(path: String, buffer: Buffer) raises:
    from .streams import _open
    var descriptor = _open(path, "a", None)
    try:
        _ = descriptor.write(buffer, None)
    finally:
        descriptor.close()


def append_text_file(path: String, value: String) raises:
    append_file(path, Buffer.from_string(value))


def make_directory_default(path: String) raises:
    mkdir(Path(path), mode=0o777)


def make_directory(path: String, options: MkdirOptions = MkdirOptions()) raises:
    var recursive = options.recursive.value() if options.recursive else False
    checked_path(path)
    var mode = Int(checked_integer(options.mode.value(), 4294967295, "mode")) if options.mode else 0o777
    if recursive:
        makedirs(Path(path), mode=mode, exist_ok=True)
    else:
        mkdir(Path(path), mode=mode)


def read_directory_names(path: String) raises -> List[String]:
    var result = List[String]()
    for child in Path(path).listdir():
        result.append(child.name())
    return result^


def read_directory(
    path: String,
    options: ReaddirOptions,
) raises -> List[Dirent]:
    if not options.with_file_types:
        raise Error("Dirent results require withFileTypes: true")
    var result = List[Dirent]()
    var parent = Path(path)
    for child in parent.listdir():
        var name = child.name()
        var child_path = parent / child
        var symbolic = std.os.path.islink(child_path)
        result.append(
            Dirent(
                name^,
                child_path.is_file() and not symbolic,
                child_path.is_dir() and not symbolic,
                symbolic,
            )
        )
    return result^


def remove_path_default(path: String) raises:
    remove_path(path, RmOptions())


def remove_path(path: String, options: RmOptions) raises:
    checked_path(path)
    var retries = UInt32(checked_integer(options.max_retries.value(), 4294967295, "maxRetries")) if options.max_retries else UInt32(0)
    var delay = UInt32(checked_integer(options.retry_delay.value(), 4294967295, "retryDelay")) if options.retry_delay else UInt32(100)
    var status = external_call["tsonic_node_fs_remove", Int32](
        path.as_c_string_slice(), c_int(options.recursive.value() if options.recursive else False),
        c_int(options.force.value() if options.force else False), retries, delay,
    )
    check_status(status, "rm")


def make_temp_directory(prefix: String) raises -> String:
    var process = Int(external_call["getpid", c_int]())
    for attempt in range(1024):
        var candidate = prefix + String(process) + "-" + String(attempt)
        if exists(candidate):
            continue
        try:
            mkdir(Path(candidate), mode=0o700)
            return candidate^
        except:
            pass
    raise Error("Unable to create a unique temporary directory")


def unlink(path: String) raises:
    remove(Path(path))


def copy_file(source: String, destination: String, mode: Float64 = 0) raises:
    checked_path(source)
    checked_path(destination)
    var flags = c_int(checked_integer(mode, 7, "copy mode"))
    check_status(external_call["tsonic_node_fs_copy", Int32](
        source.as_c_string_slice(), destination.as_c_string_slice(), flags,
    ), "copyFile")


def rename_path(source: String, destination: String) raises:
    var source_buffer = source
    var destination_buffer = destination
    var status = external_call["rename", c_int](
        source_buffer.as_c_string_slice(),
        destination_buffer.as_c_string_slice(),
    )
    if status != 0:
        raise Error("Unable to rename path; errno ", get_errno())


def symbolic_link(target: String, path: String) raises:
    symlink(Path(target), Path(path))


def real_path(path: String) raises -> String:
    return std.os.path.realpath(Path(path))
