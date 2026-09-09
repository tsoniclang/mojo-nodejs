from std.ffi import c_int, c_size_t, external_call, get_errno
from ..buffer import Buffer
from .validation import checked_integer, checked_path, check_status


def open_file(path: String, flags: String, mode: Float64 = 0o666) raises -> Float64:
    checked_path(path)
    checked_path(flags)
    var permissions = UInt32(checked_integer(mode, 4294967295, "mode"))
    var descriptor = external_call["tsonic_node_fs_open", c_int](
        path.as_c_string_slice(), flags.as_c_string_slice(), permissions,
    )
    if descriptor < 0:
        raise Error("Unable to open file: ", get_errno())
    return Float64(descriptor)


def close_file(descriptor: Float64) raises:
    var number = c_int(checked_integer(descriptor, 2147483647, "descriptor"))
    if external_call["close", c_int](number) != 0:
        raise Error("Unable to close file: ", get_errno())


def _position(value: Optional[Float64]) raises -> Optional[Int64]:
    return Optional(checked_integer(value.value(), 9007199254740991, "position")) if value else None


def read_into(descriptor: Float64, buffer: Buffer, offset: Float64, length: Float64,
              position: Optional[Float64] = None) raises -> Float64:
    var number = c_int(checked_integer(descriptor, 2147483647, "descriptor"))
    var first = Int(checked_integer(offset, Float64(len(buffer)), "buffer offset"))
    var count = Int(checked_integer(length, Float64(len(buffer) - first), "buffer length"))
    var location = _position(position)
    if count == 0:
        return 0
    var read = external_call["tsonic_node_stream_read", Int64](
        number, buffer._bytes[].unsafe_ptr().unsafe_offset(buffer._offset + first), c_size_t(count),
        location.value() if location else Int64(0), c_int(Bool(location)),
    )
    if read < 0:
        raise Error("Unable to read file: ", get_errno())
    return Float64(read)


def write_from(descriptor: Float64, buffer: Buffer, offset: Float64 = 0,
               length: Optional[Float64] = None, position: Optional[Float64] = None) raises -> Float64:
    var number = c_int(checked_integer(descriptor, 2147483647, "descriptor"))
    var first = Int(checked_integer(offset, Float64(len(buffer)), "buffer offset"))
    var count = Int(checked_integer(length.value(), Float64(len(buffer) - first), "buffer length")) if length else len(buffer) - first
    var location = _position(position)
    if count == 0:
        return 0
    var written = external_call["tsonic_node_stream_write", Int64](
        number, buffer._bytes[].unsafe_ptr().unsafe_offset(buffer._offset + first), c_size_t(count),
        location.value() if location else Int64(0), c_int(Bool(location)),
    )
    if written < 0:
        raise Error("Unable to write file: ", get_errno())
    return Float64(written)


def write_string(descriptor: Float64, value: String, position: Optional[Float64] = None,
                 encoding: String = "utf8") raises -> Float64:
    from ..buffer import buffer_from_string_encoded
    return write_from(descriptor, buffer_from_string_encoded(value, encoding), 0, None, position)


def access(path: String, mode: Float64 = 0) raises:
    checked_path(path)
    var permissions = c_int(checked_integer(mode, 7, "access mode"))
    check_status(external_call["tsonic_node_fs_access", Int32](path.as_c_string_slice(), permissions), "access")


def chmod(path: String, mode: Float64) raises:
    checked_path(path)
    var permissions = c_int(checked_integer(mode, 0o7777, "permission mode"))
    check_status(external_call["tsonic_node_fs_chmod", Int32](path.as_c_string_slice(), permissions), "chmod")


def truncate_file(path: String, length: Float64 = 0) raises:
    var size = checked_integer(length, 9007199254740991, "length")
    var descriptor = open_file(path, "r+")
    try:
        if external_call["ftruncate", c_int](c_int(descriptor), size) != 0:
            raise Error("Unable to truncate file: ", get_errno())
    finally:
        close_file(descriptor)
