from std.collections import Deque
from std.memory import ArcPointer


@fieldwise_init
struct _TextChunk(ImplicitlyCopyable):
    var storage: ArcPointer[String]
    var start: Int
    var length: Int


def _unit_length(text: String) -> Int:
    var result = 0
    for point in text.codepoints():
        result += 2 if point.to_u32() > 0xFFFF else 1
    return result


def _end_byte(chunk: _TextChunk, units: Int) raises -> Int:
    var bytes = chunk.storage[].as_bytes()
    var offset = chunk.start
    var remaining = units
    while remaining > 0:
        var lead = bytes[offset]
        var size = 1 if lead < 0x80 else 2 if lead < 0xE0 else 3 if lead < 0xF0 else 4
        var count = 2 if size == 4 else 1
        if remaining < count:
            raise Error("Decoded stream read would split a surrogate pair; native strings cannot represent that result")
        remaining -= count
        offset += size
    return offset


struct TextQueue(Movable):
    var _chunks: Deque[_TextChunk]
    var length: Int

    def __init__(out self):
        self._chunks = Deque[_TextChunk]()
        self.length = 0

    def append(mut self, var text: String) raises:
        var units = _unit_length(text)
        if units == 0:
            return
        if units > 9007199254740991 - self.length:
            raise Error("Stream decoded length exceeds the exact source range")
        self._chunks.append(_TextChunk(ArcPointer(text^), 0, units))
        self.length += units

    def clear(mut self):
        self._chunks.clear()
        self.length = 0

    def take(mut self, size: Int) raises -> Optional[String]:
        if size < 0 or size > self.length:
            raise Error("Stream read exceeds its retained text")
        if size == 0:
            return None
        var remaining = size
        var output_bytes = 0
        for chunk in self._chunks:
            var count = min(remaining, chunk.length)
            output_bytes += _end_byte(chunk, count) - chunk.start
            remaining -= count
            if remaining == 0:
                break
        var output = String(capacity_bytes=output_bytes)
        remaining = size
        while remaining:
            var chunk = self._chunks.popleft()
            var count = min(remaining, chunk.length)
            var end = _end_byte(chunk, count)
            output += chunk.storage[][byte=chunk.start:end]
            remaining -= count
            if count < chunk.length:
                self._chunks.appendleft(_TextChunk(chunk.storage, end, chunk.length - count))
        self.length -= size
        return Optional(output^)
