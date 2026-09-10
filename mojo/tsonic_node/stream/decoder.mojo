from std.collections import List
from ..buffer import Buffer
from ..buffer.codec import decode_bytes, encoding_name


def _utf8_boundary(bytes: List[Byte]) -> Int:
    var stop = len(bytes)
    if stop == 0:
        return stop
    var start = stop - 1
    while start > 0 and stop - start < 4 and bytes[start] & 0xC0 == 0x80:
        start -= 1
    var lead = bytes[start]
    var needed = 2 if 0xC2 <= lead <= 0xDF else 3 if 0xE0 <= lead <= 0xEF else 4 if 0xF0 <= lead <= 0xF4 else 0
    if needed == 0 or stop - start >= needed:
        return stop
    for index in range(start + 1, stop):
        if bytes[index] & 0xC0 != 0x80:
            return stop
    if start + 1 < stop:
        var second = bytes[start + 1]
        if (lead == 0xE0 and second < 0xA0) or (lead == 0xED and second > 0x9F) or (lead == 0xF0 and second < 0x90) or (lead == 0xF4 and second > 0x8F):
            return stop
    return start


struct StreamDecoder(Movable):
    var name: String
    var _pending: List[Byte]

    def __init__(out self):
        self.name = "utf8"
        self._pending = List[Byte]()

    def __init__(out self, name: String) raises:
        self.name = encoding_name(name)
        self._pending = List[Byte]()

    def write(mut self, value: Buffer) raises -> String:
        var bytes = List[Byte](capacity=len(self._pending) + len(value))
        for byte in self._pending:
            bytes.append(byte)
        for index in range(len(value)):
            bytes.append(value._bytes[][value._offset + index])
        var boundary = len(bytes)
        if self.name == "utf8":
            boundary = _utf8_boundary(bytes)
        elif self.name == "utf16le":
            boundary -= boundary % 2
            if boundary >= 2:
                var last = UInt16(bytes[boundary - 2]) | (UInt16(bytes[boundary - 1]) << 8)
                if 0xD800 <= last <= 0xDBFF:
                    boundary -= 2
        elif self.name == "base64" or self.name == "base64url":
            boundary -= boundary % 3
        var pending = List[Byte]()
        for index in range(boundary, len(bytes)):
            pending.append(bytes[index])
        while len(bytes) > boundary:
            _ = bytes.pop()
        var output = decode_bytes(bytes, self.name)
        self._pending = pending^
        return output^

    def end(mut self) raises -> String:
        var output = decode_bytes(self._pending, self.name)
        self._pending.clear()
        return output^
