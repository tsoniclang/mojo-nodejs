from std.collections import List
from std.memory import ArcPointer


struct Buffer(ImplicitlyCopyable, Sized):
    var _bytes: ArcPointer[List[Byte]]
    var _offset: Int
    var _length: Int

    def __init__(out self):
        self._bytes = ArcPointer(List[Byte]())
        self._offset = 0
        self._length = 0

    def __init__(out self, var bytes: List[Byte]):
        self._length = len(bytes)
        self._bytes = ArcPointer(bytes^)
        self._offset = 0

    def __init__(
        out self,
        storage: ArcPointer[List[Byte]],
        offset: Int,
        length: Int,
    ):
        self._bytes = storage
        self._offset = offset
        self._length = length

    @staticmethod
    def allocate(size: Int, fill: UInt8 = 0) raises -> Self:
        if size < 0:
            raise Error("Buffer size cannot be negative")
        var bytes = List[Byte](capacity=size)
        for _ in range(size):
            bytes.append(Byte(fill))
        return Self(bytes^)

    @staticmethod
    def from_string(value: String) -> Self:
        var bytes = List[Byte](capacity=value.byte_length())
        for byte in value.as_bytes():
            bytes.append(byte)
        return Self(bytes^)

    def __len__(self) -> Int:
        return self._length

    def get(self, index: Int) raises -> UInt8:
        self._validate_index(index)
        return UInt8(self._bytes[][self._offset + index])

    def set(mut self, index: Int, value: UInt8) raises:
        self._validate_index(index)
        self._bytes[][self._offset + index] = Byte(value)

    def subarray(self, start: Int = 0, end: Optional[Int] = None) -> Self:
        var bounded_start = Self._bound_index(start, self._length)
        var bounded_end = Self._bound_index(
            end.value(), self._length
        ) if end else self._length
        if bounded_end < bounded_start:
            bounded_end = bounded_start
        return Self(
            self._bytes,
            self._offset + bounded_start,
            bounded_end - bounded_start,
        )

    def copy_bytes(self) -> List[Byte]:
        var result = List[Byte](capacity=self._length)
        for index in range(self._length):
            result.append(self._bytes[][self._offset + index])
        return result^

    def to_string(self) raises -> String:
        return String(from_utf8=self.copy_bytes())

    def same_storage(self, other: Self) -> Bool:
        return self._bytes is other._bytes

    def _validate_index(self, index: Int) raises:
        if index < 0 or index >= self._length:
            raise Error("Buffer index is outside the valid range")

    @staticmethod
    def _bound_index(index: Int, length: Int) -> Int:
        if index < 0:
            return max(length + index, 0)
        return min(index, length)
