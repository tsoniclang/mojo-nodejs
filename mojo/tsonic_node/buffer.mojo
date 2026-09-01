from std.collections import List
from std.base64 import b64decode, b64encode
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

    def js_length(self) -> Float64:
        return Float64(self._length)

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

    def slice(self, start: Int = 0, end: Optional[Int] = None) -> Self:
        return self.subarray(start, end)

    def copy(
        self,
        target: Self,
        target_start: Int = 0,
        source_start: Int = 0,
        source_end: Optional[Int] = None,
    ) raises -> Float64:
        var source_first = Self._bound_index(source_start, self._length)
        var source_last = Self._bound_index(
            source_end.value(), self._length
        ) if source_end else self._length
        var target_first = Self._bound_index(target_start, target._length)
        var count = min(
            max(source_last - source_first, 0),
            target._length - target_first,
        )
        var copied = List[Byte](capacity=count)
        for index in range(count):
            copied.append(self._bytes[][self._offset + source_first + index])
        for index in range(count):
            target._bytes[][target._offset + target_first + index] = copied[
                index
            ]
        return Float64(count)

    def equals(self, other: Self) -> Bool:
        return self.compare(other) == 0

    def compare(self, other: Self) -> Float64:
        var shared = min(self._length, other._length)
        for index in range(shared):
            var left = self._bytes[][self._offset + index]
            var right = other._bytes[][other._offset + index]
            if left < right:
                return -1
            if left > right:
                return 1
        if self._length < other._length:
            return -1
        if self._length > other._length:
            return 1
        return 0

    def swap16(mut self) raises -> Self:
        return self._swap(2)

    def swap32(mut self) raises -> Self:
        return self._swap(4)

    def swap64(mut self) raises -> Self:
        return self._swap(8)

    def read_uint8(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 1, True))

    def read_int8(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_int(offset, 1, True))

    def read_uint16_le(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 2, True))

    def read_uint16_be(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 2, False))

    def read_int16_le(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_int(offset, 2, True))

    def read_int16_be(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_int(offset, 2, False))

    def read_uint32_le(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 4, True))

    def read_uint32_be(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 4, False))

    def read_int32_le(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_int(offset, 4, True))

    def read_int32_be(self, offset: Int = 0) raises -> Float64:
        return Float64(self._read_int(offset, 4, False))

    def read_float_le(self, offset: Int = 0) raises -> Float64:
        return Float64(
            bitcast[.float32](UInt32(self._read_uint(offset, 4, True)))
        )

    def read_float_be(self, offset: Int = 0) raises -> Float64:
        return Float64(
            bitcast[.float32](UInt32(self._read_uint(offset, 4, False)))
        )

    def read_double_le(self, offset: Int = 0) raises -> Float64:
        return bitcast[.float64](self._read_uint(offset, 8, True))

    def read_double_be(self, offset: Int = 0) raises -> Float64:
        return bitcast[.float64](self._read_uint(offset, 8, False))

    def write_uint8(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(UInt64(Int64(value)), offset, 1, True)
        return Float64(offset + 1)

    def write_int8(mut self, value: Float64, offset: Int = 0) raises -> Float64:
        return self.write_uint8(value, offset)

    def write_uint16_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(UInt64(Int64(value)), offset, 2, True)
        return Float64(offset + 2)

    def write_uint16_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(UInt64(Int64(value)), offset, 2, False)
        return Float64(offset + 2)

    def write_int16_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        return self.write_uint16_le(value, offset)

    def write_int16_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        return self.write_uint16_be(value, offset)

    def write_uint32_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(UInt64(Int64(value)), offset, 4, True)
        return Float64(offset + 4)

    def write_uint32_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(UInt64(Int64(value)), offset, 4, False)
        return Float64(offset + 4)

    def write_int32_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        return self.write_uint32_le(value, offset)

    def write_int32_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        return self.write_uint32_be(value, offset)

    def write_float_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(
            UInt64(bitcast[.uint32](Float32(value))), offset, 4, True
        )
        return Float64(offset + 4)

    def write_float_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(
            UInt64(bitcast[.uint32](Float32(value))), offset, 4, False
        )
        return Float64(offset + 4)

    def write_double_le(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(bitcast[.uint64](value), offset, 8, True)
        return Float64(offset + 8)

    def write_double_be(
        mut self, value: Float64, offset: Int = 0
    ) raises -> Float64:
        self._write_uint(bitcast[.uint64](value), offset, 8, False)
        return Float64(offset + 8)

    def copy_bytes(self) -> List[Byte]:
        var result = List[Byte](capacity=self._length)
        for index in range(self._length):
            result.append(self._bytes[][self._offset + index])
        return result^

    def to_string(self) raises -> String:
        return String(from_utf8=self.copy_bytes())

    def to_string(self, encoding: String) raises -> String:
        if encoding == "utf8" or encoding == "utf-8":
            return self.to_string()
        if encoding == "base64":
            var bytes = self.copy_bytes()
            return b64encode(Span(bytes))
        if encoding == "hex":
            return self._hex_string()
        raise Error("Unsupported Buffer encoding: ", encoding)

    def same_storage(self, other: Self) -> Bool:
        return self._bytes is other._bytes

    def _validate_index(self, index: Int) raises:
        if index < 0 or index >= self._length:
            raise Error("Buffer index is outside the valid range")

    def _validate_range(self, offset: Int, width: Int) raises:
        if offset < 0 or width < 0 or offset + width > self._length:
            raise Error("Buffer range is outside the valid range")

    def _read_uint(
        self, offset: Int, width: Int, little_endian: Bool
    ) raises -> UInt64:
        self._validate_range(offset, width)
        var result = UInt64(0)
        for index in range(width):
            var shift = 8 * (index if little_endian else width - index - 1)
            result |= (
                UInt64(self._bytes[][self._offset + offset + index]) << shift
            )
        return result

    def _read_int(
        self, offset: Int, width: Int, little_endian: Bool
    ) raises -> Int64:
        var value = self._read_uint(offset, width, little_endian)
        var bits = width * 8
        if bits < 64 and (value & (UInt64(1) << (bits - 1))):
            return Int64(value) - (Int64(1) << bits)
        return Int64(value)

    def _write_uint(
        mut self,
        value: UInt64,
        offset: Int,
        width: Int,
        little_endian: Bool,
    ) raises:
        self._validate_range(offset, width)
        for index in range(width):
            var shift = 8 * (index if little_endian else width - index - 1)
            self._bytes[][self._offset + offset + index] = Byte(
                UInt8((value >> shift) & 0xFF)
            )

    def _swap(mut self, width: Int) raises -> Self:
        if self._length % width != 0:
            raise Error("Buffer size must be a multiple of the swap width")
        for start in range(0, self._length, width):
            for offset in range(width / 2):
                var left = self._offset + start + offset
                var right = self._offset + start + width - offset - 1
                var value = self._bytes[][left]
                self._bytes[][left] = self._bytes[][right]
                self._bytes[][right] = value
        return self

    def _hex_string(self) -> String:
        comptime digits = "0123456789abcdef"
        var result = String(capacity_bytes=self._length * 2)
        for byte in self.copy_bytes():
            var value = UInt8(byte)
            result += String(digits[byte=Int(value >> 4)])
            result += String(digits[byte=Int(value & 0x0F)])
        return result^

    @staticmethod
    def _bound_index(index: Int, length: Int) -> Int:
        if index < 0:
            return max(length + index, 0)
        return min(index, length)


def buffer_from_string(value: String) -> Buffer:
    return Buffer.from_string(value)


def buffer_from_string_encoded(
    value: String, encoding: String
) raises -> Buffer:
    if encoding == "utf8" or encoding == "utf-8":
        return Buffer.from_string(value)
    if encoding == "base64":
        return Buffer(b64decode(value))
    raise Error("Unsupported Buffer encoding: ", encoding)


def buffer_from_numbers(values: List[Float64]) -> Buffer:
    var bytes = List[Byte](capacity=len(values))
    for value in values:
        bytes.append(Byte(UInt8(Int64(value) & 0xFF)))
    return Buffer(bytes^)


def buffer_alloc(size: Int) raises -> Buffer:
    return Buffer.allocate(size)


def buffer_concat(values: List[Buffer]) -> Buffer:
    var bytes = List[Byte]()
    for value in values:
        for byte in value.copy_bytes():
            bytes.append(byte)
    return Buffer(bytes^)


def buffer_byte_length(
    value: String, encoding: String = "utf8"
) raises -> Float64:
    if encoding == "utf8" or encoding == "utf-8":
        return Float64(value.byte_length())
    if encoding == "base64":
        return Float64(len(b64decode(value)))
    raise Error("Unsupported Buffer encoding: ", encoding)


def buffer_is_buffer(value: Buffer) -> Bool:
    return True


def buffer_is_encoding(encoding: String) -> Bool:
    return (
        encoding == "utf8"
        or encoding == "utf-8"
        or encoding == "base64"
        or encoding == "hex"
    )


def buffer_btoa(value: String) -> String:
    return b64encode(value)


def buffer_atob(value: String) raises -> String:
    return String(from_utf8=b64decode(value))
