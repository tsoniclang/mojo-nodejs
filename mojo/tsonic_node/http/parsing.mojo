from std.collections import List

from ..buffer import Buffer
from .messages import IncomingMessage


def parse_request_bytes(bytes: List[Byte]) raises -> IncomingMessage:
    var header_end = find_header_end(bytes)
    if header_end < 0:
        raise Error("HTTP request ended before its headers were complete")
    if header_end > 64 * 1024:
        raise Error("HTTP request headers exceed the finite runtime limit")
    var head_bytes = List[Byte](capacity=header_end)
    for index in range(header_end):
        head_bytes.append(bytes[index])
    var head = String(from_utf8=head_bytes)
    var lines = head.split("\r\n")
    if len(lines) == 0:
        raise Error("HTTP request has no request line")
    var request_parts = String(lines[0]).split(" ")
    if len(request_parts) != 3:
        raise Error("HTTP request line is invalid")
    var content_length = request_content_length(bytes, header_end)
    var body_start = header_end + 4
    if len(bytes) - body_start < content_length:
        raise Error("HTTP request ended before its body was complete")
    var body = List[Byte](capacity=content_length)
    for index in range(content_length):
        body.append(bytes[body_start + index])
    return IncomingMessage(
        String(request_parts[0]), String(request_parts[1]), Buffer(body^)
    )


def request_content_length(bytes: List[Byte], header_end: Int) raises -> Int:
    var head_bytes = List[Byte](capacity=header_end)
    for index in range(header_end):
        head_bytes.append(bytes[index])
    var lines = String(from_utf8=head_bytes).split("\r\n")
    var content_length = 0
    for index in range(1, len(lines)):
        var line = String(lines[index])
        var separator = line.find(":")
        if not separator:
            raise Error("HTTP request header is invalid")
        var name = String(line[byte = : separator.value()]).lower()
        var value = String(line[byte = separator.value() + 1 :]).strip()
        if name == "content-length":
            content_length = Int(value)
            if content_length < 0 or content_length > 64 * 1024 * 1024:
                raise Error(
                    "HTTP request body exceeds the finite runtime limit"
                )
    return content_length


def find_header_end(bytes: List[Byte]) -> Int:
    if len(bytes) < 4:
        return -1
    for index in range(len(bytes) - 3):
        if (
            bytes[index] == 13
            and bytes[index + 1] == 10
            and bytes[index + 2] == 13
            and bytes[index + 3] == 10
        ):
            return index
    return -1
