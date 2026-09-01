from std.collections import List
from std.ffi import c_int, c_size_t, c_ssize_t, external_call
from std.sys._libc import close


def close_socket(descriptor: Int32):
    if descriptor >= 0:
        _ = close(descriptor)


def send_string(descriptor: Int32, value: String) raises:
    var bytes = List[Byte](capacity=value.byte_length())
    for byte in value.as_bytes():
        bytes.append(byte)
    send_buffer(descriptor, bytes)


def send_buffer(descriptor: Int32, bytes: List[Byte]) raises:
    var offset = 0
    while offset < len(bytes):
        var sent = external_call["send", c_ssize_t](
            descriptor,
            bytes.unsafe_ptr().unsafe_offset(offset),
            c_size_t(len(bytes) - offset),
            c_int(0),
        )
        if sent <= 0:
            raise Error("Unable to write HTTP response")
        offset += sent
