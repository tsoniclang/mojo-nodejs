import std.os.path
from std.collections import List
from std.ffi import c_int, external_call, get_errno
from std.os import (
    lstat as native_lstat,
    makedirs,
    mkdir,
    remove,
    rmdir,
    stat as native_stat,
    symlink,
)
from std.pathlib import Path

from .buffer import Buffer


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

    def __init__(
        out self,
        recursive: Optional[Bool] = None,
        force: Optional[Bool] = None,
    ):
        self.recursive = recursive
        self.force = force


struct ReaddirOptions(Copyable):
    var with_file_types: Bool

    def __init__(out self, with_file_types: Bool = True):
        self.with_file_types = with_file_types


@fieldwise_init
struct Stats(Copyable):
    var size: Int
    var mtime_ms: Float64
    var mode: Int
    var device: Int
    var inode: Int
    var links: Int
    var user: Int
    var group: Int
    var _file: Bool
    var _directory: Bool
    var _symbolic_link: Bool

    def is_file(self) -> Bool:
        return self._file

    def is_directory(self) -> Bool:
        return self._directory

    def is_symbolic_link(self) -> Bool:
        return self._symbolic_link


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


def _stats(path: String, follow_links: Bool) raises -> Stats:
    var native = native_stat(Path(path)) if follow_links else native_lstat(
        Path(path)
    )
    return Stats(
        native.st_size,
        Float64(native.st_mtimespec.as_nanoseconds()) / 1_000_000.0,
        native.st_mode,
        native.st_dev,
        native.st_ino,
        native.st_nlink,
        native.st_uid,
        native.st_gid,
        std.os.path.isfile(Path(path)) if follow_links else (
            std.os.path.isfile(Path(path))
            and not std.os.path.islink(Path(path))
        ),
        std.os.path.isdir(Path(path)) if follow_links else (
            std.os.path.isdir(Path(path)) and not std.os.path.islink(Path(path))
        ),
        std.os.path.islink(Path(path)),
    )


def exists(path: String) -> Bool:
    return std.os.path.exists(Path(path))


def stat(path: String) raises -> Stats:
    return _stats(path, True)


def lstat(path: String) raises -> Stats:
    return _stats(path, False)


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
    var previous = read_file(path^) if exists(path^) else Buffer()
    var bytes = previous.copy_bytes()
    for byte in buffer.copy_bytes():
        bytes.append(byte)
    Path(path).write_bytes(Span(bytes))


def append_text_file(path: String, value: String) raises:
    append_file(path, Buffer.from_string(value))


def make_directory_default(path: String) raises:
    mkdir(Path(path), mode=0o777)


def make_directory(path: String, options: MkdirOptions = MkdirOptions()) raises:
    var recursive = options.recursive.value() if options.recursive else False
    var mode = Int(options.mode.value()) if options.mode else 0o777
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
    var path_value = Path(path)
    if not std.os.path.lexists(path_value):
        if options.force and options.force.value():
            return
        raise Error("Path does not exist: ", path)

    if std.os.path.islink(path_value) or path_value.is_file():
        remove(path_value)
        return

    if path_value.is_dir():
        if not options.recursive or not options.recursive.value():
            rmdir(path_value)
            return
        for child in path_value.listdir():
            remove_path(
                String(path_value / child),
                RmOptions(
                    recursive=Optional[Bool](True),
                    force=options.force,
                ),
            )
        rmdir(path_value)
        return

    remove(path_value)


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


def copy_file(source: String, destination: String) raises:
    var bytes = Path(source).read_bytes()
    Path(destination).write_bytes(Span(bytes))


def rename_path(var source: String, var destination: String) raises:
    var status = external_call["rename", c_int](
        source.as_c_string_slice(), destination.as_c_string_slice()
    )
    if status != 0:
        raise Error("Unable to rename path; errno ", get_errno())


def symbolic_link(target: String, path: String) raises:
    symlink(Path(target), Path(path))


def real_path(path: String) raises -> String:
    return std.os.path.realpath(Path(path))
