import std.os.path
from std.collections import List, Span
from .url import URL
from ..buffer import Buffer


def path_to_file_url(path: String) raises -> URL:
    var absolute = std.os.path.abspath(path)
    if path.endswith("/") and not absolute.endswith("/"):
        absolute += "/"
    var escaped_bytes = List[Byte](capacity=absolute.byte_length())
    var digits = "0123456789ABCDEF".as_bytes()
    for byte in absolute.as_bytes():
        var value = UInt8(byte)
        if value == 0 or value == 9 or value == 10 or value == 13 or value == 32 or value == 34 or value == 35 or value == 37 or value == 63 or value == 91 or value == 92 or value == 93 or value == 94 or value == 124 or value == 126:
            escaped_bytes.append(Byte(37))
            escaped_bytes.append(digits[Int(value >> 4)])
            escaped_bytes.append(digits[Int(value & 15)])
        else:
            escaped_bytes.append(byte)
    var escaped = String(unsafe_from_utf8=Span(escaped_bytes))
    var result = URL("file:///")
    result.set_pathname(escaped)
    return result


def _hex_digit(value: UInt8) raises -> UInt8:
    if value >= 48 and value <= 57:
        return value - 48
    if value >= 65 and value <= 70:
        return value - 65 + 10
    if value >= 97 and value <= 102:
        return value - 97 + 10
    raise Error("Invalid percent escape in file URL")


def file_url_to_path_buffer(url: URL) raises -> Buffer:
    if url.protocol() != "file:":
        raise Error("fileURLToPath requires the file: protocol")
    var host = url.hostname()
    if host != "" and host != "localhost":
        raise Error("A POSIX file URL cannot have a remote hostname")
    var path = url.pathname()
    var bytes = path.as_bytes()
    var decoded = List[Byte](capacity=len(bytes))
    var index = 0
    while index < len(bytes):
        var byte = UInt8(bytes[index])
        if byte == 37:
            if index + 2 >= len(bytes):
                raise Error("Invalid percent escape in file URL")
            byte = (_hex_digit(UInt8(bytes[index + 1])) << 4) | _hex_digit(UInt8(bytes[index + 2]))
            if byte == 47:
                raise Error("A file URL cannot contain an encoded path separator")
            index += 2
        decoded.append(Byte(byte))
        index += 1
    return Buffer(decoded^)


def file_url_to_path(url: URL) raises -> String:
    var bytes = file_url_to_path_buffer(url).copy_bytes()
    return String(from_utf8=Span(bytes))


def file_url_to_path(input: String) raises -> String:
    return file_url_to_path(URL(input))


def file_url_to_path_buffer(input: String) raises -> Buffer:
    return file_url_to_path_buffer(URL(input))
