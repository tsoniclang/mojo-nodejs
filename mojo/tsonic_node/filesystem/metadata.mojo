from std.collections import List
from std.ffi import c_char, c_int, external_call
from tsonic_js.date import JsDate
from .validation import checked_integer, checked_path, check_status


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
    var atime_ms: Float64
    var ctime_ms: Float64
    var birthtime_ms: Float64

    def is_file(self) -> Bool:
        return self._file

    def is_directory(self) -> Bool:
        return self._directory

    def is_symbolic_link(self) -> Bool:
        return self._symbolic_link

    def atime(self) -> JsDate:
        return JsDate(self.atime_ms)

    def mtime(self) -> JsDate:
        return JsDate(self.mtime_ms)

    def ctime(self) -> JsDate:
        return JsDate(self.ctime_ms)

    def birthtime(self) -> JsDate:
        return JsDate(self.birthtime_ms)


def _snapshot(value: Pointer[NoneType, MutUntrackedOrigin]) -> Stats:
    var fields = List[Int](capacity=10)
    for field in range(10):
        fields.append(
            Int(
                external_call["tsonic_node_fs_stat_field", Int64](
                    value, c_int(field)
                )
            )
        )
    return Stats(
        fields[0],
        external_call["tsonic_node_fs_stat_time", Float64](value, c_int(1)),
        fields[1],
        fields[2],
        fields[3],
        fields[4],
        fields[5],
        fields[6],
        fields[7] != 0,
        fields[8] != 0,
        fields[9] != 0,
        external_call["tsonic_node_fs_stat_time", Float64](value, c_int(0)),
        external_call["tsonic_node_fs_stat_time", Float64](value, c_int(2)),
        external_call["tsonic_node_fs_stat_time", Float64](value, c_int(3)),
    )


def stat_if_present(path: String, follow: Bool = True) raises -> Optional[Stats]:
    checked_path(path)
    var status = c_int(0)
    var native_path = path
    var path_pointer: OptionalPointer[c_char, ImmutAnyOrigin] = (
        native_path.as_c_string_slice().ptr().as_unsafe_any_origin()
    )
    var value = external_call[
        "tsonic_node_fs_stat", OptionalPointer[NoneType, MutUntrackedOrigin]
    ](
        path_pointer,
        c_int(-1),
        c_int(follow),
        Pointer(to=status),
    )
    if external_call["tsonic_node_fs_missing", c_int](status):
        return None
    check_status(Int32(status), "stat")
    try:
        return _snapshot(value.value())
    finally:
        external_call["tsonic_node_fs_free", NoneType](value.value())


def _stat(path: String, follow: Bool) raises -> Stats:
    var result = stat_if_present(path, follow)
    if not result:
        raise Error("stat: ENOENT: no such file or directory: ", path)
    return result.value()


def stat(path: String) raises -> Stats:
    return _stat(path, True)


def lstat(path: String) raises -> Stats:
    return _stat(path, False)


def fstat(descriptor: Float64) raises -> Stats:
    var number = c_int(checked_integer(descriptor, 2147483647, "descriptor"))
    var status = c_int(0)
    var value = external_call[
        "tsonic_node_fs_stat", OptionalPointer[NoneType, MutUntrackedOrigin]
    ](
        OptionalPointer[c_char, ImmutAnyOrigin](),
        number,
        c_int(0),
        Pointer(to=status),
    )
    check_status(Int32(status), "fstat")
    try:
        return _snapshot(value.value())
    finally:
        external_call["tsonic_node_fs_free", NoneType](value.value())
