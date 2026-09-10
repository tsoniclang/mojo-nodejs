from std.collections import Deque
from ..buffer import Buffer


struct ByteQueue(Movable):
    var _chunks: Deque[Buffer]
    var length: Int

    def __init__(out self):
        self._chunks = Deque[Buffer]()
        self.length = 0

    def append(mut self, value: Buffer) raises:
        if len(value) == 0:
            return
        if len(value) > 9007199254740991 - self.length:
            raise Error("Stream buffered byte count exceeds the exact source range")
        self._chunks.append(value)
        self.length += len(value)

    def clear(mut self):
        self._chunks.clear()
        self.length = 0

    def take(mut self, size: Int) raises -> Optional[Buffer]:
        if size < 0 or size > self.length:
            raise Error("Stream read exceeds its retained bytes")
        if size == 0:
            return None
        var first = self._chunks.popleft()
        self.length -= size
        if len(first) == size:
            return first
        if len(first) > size:
            self._chunks.appendleft(first.subarray(Float64(size)))
            return first.subarray(0, Float64(size))
        var result = Buffer.allocate(size)
        _ = first.copy(result)
        var copied = len(first)
        while copied < size:
            var next = self._chunks.popleft()
            var count = min(len(next), size - copied)
            _ = next.copy(result, Float64(copied), 0, Float64(count))
            copied += count
            if count < len(next):
                self._chunks.appendleft(next.subarray(Float64(count)))
        return result
