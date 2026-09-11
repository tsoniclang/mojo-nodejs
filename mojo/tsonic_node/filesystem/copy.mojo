from std.collections import List
from std.ffi import external_call
from std.pathlib import Path
from .copy_options import CopyOptions
from .core import (
    MkdirOptions,
    make_directory,
    read_directory_names,
    copy_file,
    unlink,
    symbolic_link,
)
from .descriptors import chmod
from .links import read_link
from .metadata import Stats, stat, lstat, stat_if_present
from .validation import checked_path, checked_integer, check_status
from ..path import dirname, is_absolute, resolve


def _absolute(path: String) raises -> String:
    var paths: List[String] = [path]
    return resolve(paths)


def _within(source: String, destination: String) raises -> Bool:
    var parent = _absolute(source)
    var child = _absolute(destination)
    return child == parent or child.startswith(
        parent + ("" if parent.endswith("/") else "/")
    )


def _same(left: Stats, right: Stats) -> Bool:
    return (
        left.inode != 0
        and left.device != 0
        and left.inode == right.inode
        and left.device == right.device
    )


@fieldwise_init
struct CopyEntry(Copyable):
    var source: String
    var destination: String
    var finish_mode: Optional[Int]


struct CopyTraversal:
    var _options: CopyOptions
    var _pending: List[CopyEntry]
    var _ancestors: List[Stats]
    var _mode: Float64
    var _async: Bool

    def __init__(
        out self,
        source: String,
        destination: String,
        options: CopyOptions,
        asynchronous: Bool = False,
    ) raises:
        checked_path(source)
        checked_path(destination)
        self._options = options.copy()
        self._pending = List[CopyEntry]()
        self._pending.append(CopyEntry(source, destination, None))
        self._ancestors = List[Stats]()
        self._mode = Float64(
            checked_integer(options.mode.value(), 7, "copy mode")
        ) if options.mode else 0
        self._async = asynchronous

    def next(mut self) raises -> Optional[CopyEntry]:
        while len(self._pending):
            var entry = self._pending.pop()
            if entry.finish_mode:
                if entry.finish_mode.value() >= 0:
                    chmod(entry.destination, Float64(entry.finish_mode.value()))
                _ = self._ancestors.pop()
            else:
                return entry^
        return None

    def finish(mut self) raises:
        while len(self._pending):
            var entry = self._pending.pop()
            if Bool(entry.finish_mode) and entry.finish_mode.value() >= 0:
                chmod(entry.destination, Float64(entry.finish_mode.value()))

    def accept(mut self, entry: CopyEntry) raises:
        var follow = (
            self._options.dereference.value() if self._options.dereference else False
        )
        var source = stat(entry.source) if follow else lstat(entry.source)
        var destination = stat_if_present(entry.destination, follow)
        if destination:
            if _same(source, destination.value()):
                raise Error("cp: EINVAL: source and destination are the same")
            if source.is_directory() != destination.value().is_directory():
                raise Error(
                    "cp: incompatible directory and non-directory operands"
                )
        if source.is_directory():
            if (
                not self._options.recursive
                or not self._options.recursive.value()
            ):
                raise Error("cp: EISDIR: recursive option is required")
            if _within(entry.source, entry.destination):
                raise Error("cp: EINVAL: cannot copy a directory into itself")
            for ancestor in self._ancestors:
                if _same(source, ancestor):
                    raise Error(
                        "cp: ELOOP: symbolic link creates a directory cycle"
                    )
            var parent = _absolute(dirname(entry.destination))
            while True:
                var parent_stat = stat_if_present(parent)
                if parent_stat and _same(source, parent_stat.value()):
                    raise Error(
                        "cp: EINVAL: destination parent aliases the source"
                    )
                var next_parent = dirname(parent)
                if next_parent == parent:
                    break
                parent = next_parent
        make_directory(dirname(entry.destination), MkdirOptions(True))
        if source.is_directory():
            self._directory(entry, source, destination)
        elif source.is_symbolic_link():
            self._link(entry, destination)
        elif (
            source.is_file()
            or (source.mode & 0o170000) == 0o020000
            or (source.mode & 0o170000) == 0o060000
        ):
            self._file(entry, source, destination)
        else:
            raise Error("cp: EINVAL: unsupported filesystem object")

    def _directory(
        mut self, entry: CopyEntry, source: Stats, destination: Optional[Stats]
    ) raises:
        if not destination:
            make_directory(entry.destination)
        elif (
            self._async
            and Bool(self._options.error_on_exist)
            and self._options.error_on_exist.value()
            and Bool(self._options.force)
            and not self._options.force.value()
        ):
            raise Error("cp: EEXIST: destination directory exists")
        self._ancestors.append(source.copy())
        self._pending.append(
            CopyEntry(
                entry.source,
                entry.destination,
                source.mode if not destination else -1,
            )
        )
        var names = read_directory_names(entry.source)
        for index in range(len(names) - 1, -1, -1):
            self._pending.append(
                CopyEntry(
                    String(Path(entry.source) / names[index]),
                    String(Path(entry.destination) / names[index]),
                    None,
                )
            )

    def _file(
        self, entry: CopyEntry, source: Stats, destination: Optional[Stats]
    ) raises:
        if destination:
            var force = (
                self._options.force.value() if self._options.force else True
            )
            if not force:
                if (
                    Bool(self._options.error_on_exist)
                    and self._options.error_on_exist.value()
                ):
                    raise Error("cp: EEXIST: destination exists")
                return
            unlink(entry.destination)
        copy_file(entry.source, entry.destination, self._mode)
        if (
            Bool(self._options.preserve_timestamps)
            and self._options.preserve_timestamps.value()
        ):
            if (source.mode & 0o200) == 0:
                chmod(entry.destination, Float64(source.mode | 0o200))
            var updated = stat(entry.source)
            var destination_path = entry.destination.copy()
            check_status(
                external_call["tsonic_node_fs_utimes", Int32](
                    destination_path.as_c_string_slice().ptr(),
                    updated.atime_ms / 1000,
                    updated.mtime_ms / 1000,
                ),
                "cp.utimes",
            )
        chmod(entry.destination, Float64(source.mode))

    def _link(self, entry: CopyEntry, destination: Optional[Stats]) raises:
        var target = read_link(entry.source)
        var verbatim = (
            self._options.verbatim_symlinks.value() if self._options.verbatim_symlinks else False
        )
        if not verbatim and not is_absolute(target):
            target = _absolute(String(Path(dirname(entry.source)) / target))
        if destination:
            if not destination.value().is_symbolic_link():
                raise Error("cp: EEXIST: symlink destination already exists")
            var previous = read_link(entry.destination)
            if not is_absolute(previous):
                previous = _absolute(
                    String(Path(dirname(entry.destination)) / previous)
                )
            var source_stat = stat_if_present(entry.source)
            if (
                source_stat
                and source_stat.value().is_directory()
                and _within(target, previous)
            ):
                raise Error("cp: EINVAL: symlink destination is inside source")
            var destination_stat = stat(entry.destination)
            if destination_stat.is_directory() and _within(previous, target):
                raise Error("cp: EINVAL: symlink source is inside destination")
            unlink(entry.destination)
        symbolic_link(target, entry.destination)


def copy_tree(
    source: String, destination: String, options: CopyOptions = CopyOptions()
) raises:
    var traversal = CopyTraversal(source, destination, options)
    try:
        while True:
            var entry = traversal.next()
            if not entry:
                return
            if options.filter and not options.filter.value().call(
                (entry.value().source, entry.value().destination)
            ):
                continue
            traversal.accept(entry.value())
    finally:
        traversal.finish()
