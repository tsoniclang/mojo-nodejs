from std.collections import Span
from std.ffi import c_int, c_size_t, external_call
from .validation import checked_path, check_status


def read_link(path: String) raises -> String:
    checked_path(path)
    var length = c_size_t(0)
    var status = c_int(0)
    var native_path = path
    var value = external_call[
        "tsonic_node_fs_readlink", OptionalPointer[Byte, MutUntrackedOrigin]
    ](
        native_path.as_c_string_slice(),
        Pointer(to=length),
        Pointer(to=status),
    )
    check_status(Int32(status), "readlink")
    try:
        return String(from_utf8_lossy=Span(value.value(), Int(length)))
    finally:
        external_call["tsonic_node_fs_free", NoneType](value.value())
