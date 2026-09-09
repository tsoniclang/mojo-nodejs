from std.collections import List, Span
from std.collections.string import StringSpan
from std.memory import ArcPointer, bitcast
from tsonic_runtime.numeric import source_number_to_uint32
from ..validation import checked_integer
from .codec import decode_bytes, encode_bytes, encoding_name, writable_byte_count
from .search import search_bytes, search_number
from .ranges import copy_offset, clamp_offset, slice_offset


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

    def subarray(self, start: Float64 = 0, end: Optional[Float64] = None) -> Self:
        var bounded_start = slice_offset(start, self._length)
        var bounded_end = slice_offset(
            end.value(), self._length
        ) if end else self._length
        if bounded_end < bounded_start:
            bounded_end = bounded_start
        return Self(
            self._bytes,
            self._offset + bounded_start,
            bounded_end - bounded_start,
        )

    def slice(self, start: Float64 = 0, end: Optional[Float64] = None) -> Self:
        return self.subarray(start, end)

    def copy(
        self,
        target: Self,
        target_start: Float64 = 0,
        source_start: Float64 = 0,
        source_end: Optional[Float64] = None,
    ) raises -> Float64:
        var source_first = copy_offset(source_start)
        var source_last = copy_offset(source_end.value()) if source_end else self._length
        var target_first = copy_offset(target_start)
        if source_first < 0 or source_first > self._length or source_last < 0 or target_first < 0:
            raise Error("Buffer copy offset is outside the valid range")
        if target_first >= target._length or source_first >= source_last:
            return 0
        var count = min(
            min(source_last, self._length) - source_first,
            target._length - target_first,
        )
        var source_position = self._offset + source_first
        var target_position = target._offset + target_first
        if self.same_storage(target) and target_position > source_position and target_position < source_position + count:
            for index in range(count - 1, -1, -1):
                target._bytes[][target_position + index] = self._bytes[][source_position + index]
        else:
            for index in range(count):
                target._bytes[][target_position + index] = self._bytes[][source_position + index]
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

    def read_uint8(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 1, True))

    def read_int8(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_int(offset, 1, True))

    def read_uint16_le(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 2, True))

    def read_uint16_be(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 2, False))

    def read_int16_le(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_int(offset, 2, True))

    def read_int16_be(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_int(offset, 2, False))

    def read_uint32_le(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 4, True))

    def read_uint32_be(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_uint(offset, 4, False))

    def read_int32_le(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_int(offset, 4, True))

    def read_int32_be(self, offset: Float64 = 0) raises -> Float64:
        return Float64(self._read_int(offset, 4, False))

    def read_float_le(self, offset: Float64 = 0) raises -> Float64:
        return Float64(
            bitcast[.float32](UInt32(self._read_uint(offset, 4, True)))
        )

    def read_float_be(self, offset: Float64 = 0) raises -> Float64:
        return Float64(
            bitcast[.float32](UInt32(self._read_uint(offset, 4, False)))
        )

    def read_double_le(self, offset: Float64 = 0) raises -> Float64:
        return bitcast[.float64](self._read_uint(offset, 8, True))

    def read_double_be(self, offset: Float64 = 0) raises -> Float64:
        return bitcast[.float64](self._read_uint(offset, 8, False))

    def write_uint8(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 1, True, False)
        return offset + 1

    def write_int8(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 1, True, True)
        return offset + 1

    def write_uint16_le(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 2, True, False)
        return offset + 2

    def write_uint16_be(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 2, False, False)
        return offset + 2

    def write_int16_le(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 2, True, True)
        return offset + 2

    def write_int16_be(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 2, False, True)
        return offset + 2

    def write_uint32_le(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 4, True, False)
        return offset + 4

    def write_uint32_be(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 4, False, False)
        return offset + 4

    def write_int32_le(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 4, True, True)
        return offset + 4

    def write_int32_be(mut self, value: Float64, offset: Float64 = 0) raises -> Float64:
        self._write_number(value, offset, 4, False, True)
        return offset + 4

    def write_float_le(
        mut self, value: Float64, offset: Float64 = 0
    ) raises -> Float64:
        self._write_uint(
            UInt64(bitcast[.uint32](Float32(value))), offset, 4, True
        )
        return Float64(offset + 4)

    def write_float_be(
        mut self, value: Float64, offset: Float64 = 0
    ) raises -> Float64:
        self._write_uint(
            UInt64(bitcast[.uint32](Float32(value))), offset, 4, False
        )
        return Float64(offset + 4)

    def write_double_le(
        mut self, value: Float64, offset: Float64 = 0
    ) raises -> Float64:
        self._write_uint(bitcast[.uint64](value), offset, 8, True)
        return Float64(offset + 8)

    def write_double_be(
        mut self, value: Float64, offset: Float64 = 0
    ) raises -> Float64:
        self._write_uint(bitcast[.uint64](value), offset, 8, False)
        return Float64(offset + 8)

    def copy_bytes(self) -> List[Byte]:
        var result = List[Byte](capacity=self._length)
        for index in range(self._length):
            result.append(self._bytes[][self._offset + index])
        return result^

    def to_string(self, encoding: String = "utf8", start: Float64 = 0, end: Optional[Float64] = None) raises -> String:
        var first = clamp_offset(start, self._length)
        var last = clamp_offset(end.value(), self._length) if end else self._length
        if last <= first:
            return ""
        return decode_bytes(self.subarray(Float64(first), Float64(last)).copy_bytes(), encoding)

    def write(self, value: String, offset: Float64 = 0, length: Optional[Float64] = None, encoding: String = "utf8") raises -> Float64:
        var first = Int(checked_integer(offset, Float64(self._length), "offset"))
        var maximum = self._length - first
        if length:
            maximum = min(maximum, Int(checked_integer(length.value(), Float64(self._length), "length")))
        var name = encoding_name(encoding if encoding else "utf8")
        var bytes = encode_bytes(value, name)
        var count = writable_byte_count(bytes, maximum, name)
        for index in range(count):
            self._bytes[][self._offset + first + index] = bytes[index]
        return Float64(count)

    def write_encoded(self, value: String, encoding: String) raises -> Float64:
        return self.write(value, 0, None, encoding)

    def write_offset_encoded(self, value: String, offset: Float64, encoding: String) raises -> Float64:
        return self.write(value, offset, None, encoding)

    def fill_number(self, value: Float64, offset: Float64 = 0, end: Optional[Float64] = None) raises -> Self:
        var first = Int(checked_integer(offset, 9007199254740991, "offset"))
        var last = Int(checked_integer(end.value(), Float64(self._length), "end")) if end else self._length
        var byte = Byte(source_number_to_uint32(value) & 255)
        for index in range(first, last):
            self._bytes[][self._offset + index] = byte
        return self

    def fill_buffer(self, value: Self, offset: Float64 = 0, end: Optional[Float64] = None) raises -> Self:
        var first = Int(checked_integer(offset, 9007199254740991, "offset"))
        var last = Int(checked_integer(end.value(), Float64(self._length), "end")) if end else self._length
        if first >= last:
            return self
        if len(value) == 0:
            raise Error("Buffer fill pattern cannot be empty")
        var pattern = value.copy_bytes()
        for index in range(first, last):
            self._bytes[][self._offset + index] = pattern[(index - first) % len(pattern)]
        return self

    def fill_string(self, value: String, offset: Float64 = 0, end: Optional[Float64] = None, encoding: String = "utf8") raises -> Self:
        var name = encoding_name(encoding)
        if not value:
            return self.fill_number(0, offset, end)
        return self.fill_buffer(Self(encode_bytes(value, name)), offset, end)

    def fill_encoded(self, value: String, encoding: String) raises -> Self:
        return self.fill_string(value, 0, None, encoding)

    def fill_offset_encoded(self, value: String, offset: Float64, encoding: String) raises -> Self:
        return self.fill_string(value, offset, None, encoding)

    def find_buffer(self, value: Self, offset: Optional[Float64] = None, encoding: String = "utf8", reverse: Bool = False) -> Float64:
        var name = encoding.lower()
        var wide = name == "ucs2" or name == "ucs-2" or name == "utf16le" or name == "utf-16le"
        return search_bytes(Span(self._bytes[])[self._offset:self._offset + self._length], Span(value._bytes[])[value._offset:value._offset + value._length], offset, reverse, wide)

    def find_string(self, value: String, offset: Optional[Float64] = None, encoding: String = "utf8", reverse: Bool = False) raises -> Float64:
        var name = encoding_name(encoding)
        return self.find_buffer(Self(encode_bytes(value, name)), offset, name, reverse)

    def find_number(self, value: Float64, offset: Optional[Float64] = None, encoding: String = "utf8", reverse: Bool = False) -> Float64:
        return search_number(Span(self._bytes[])[self._offset:self._offset + self._length], value, offset, reverse)

    def last_buffer(self, value: Self, offset: Optional[Float64] = None, encoding: String = "utf8") -> Float64:
        return self.find_buffer(value, offset, encoding, True)

    def last_string(self, value: String, offset: Optional[Float64] = None, encoding: String = "utf8") raises -> Float64:
        return self.find_string(value, offset, encoding, True)

    def last_number(self, value: Float64, offset: Optional[Float64] = None, encoding: String = "utf8") -> Float64:
        return self.find_number(value, offset, encoding, True)

    def includes_buffer(self, value: Self, offset: Optional[Float64] = None, encoding: String = "utf8") -> Bool:
        return self.find_buffer(value, offset, encoding) >= 0

    def includes_string(self, value: String, offset: Optional[Float64] = None, encoding: String = "utf8") raises -> Bool:
        return self.find_string(value, offset, encoding) >= 0

    def includes_number(self, value: Float64, offset: Optional[Float64] = None, encoding: String = "utf8") -> Bool:
        return self.find_number(value, offset, encoding) >= 0

    def find_encoded(self, value: String, encoding: String) raises -> Float64:
        return self.find_string(value, None, encoding)

    def last_encoded(self, value: String, encoding: String) raises -> Float64:
        return self.last_string(value, None, encoding)

    def includes_encoded(self, value: String, encoding: String) raises -> Bool:
        return self.includes_string(value, None, encoding)

    def is_ascii(self) -> Bool:
        for index in range(self._length):
            if self._bytes[][self._offset + index] >= 128:
                return False
        return True

    def is_utf8(self) -> Bool:
        try:
            _ = StringSpan(from_utf8=Span(self._bytes[])[self._offset:self._offset + self._length])
            return True
        except:
            return False

    def same_storage(self, other: Self) -> Bool:
        return self._bytes is other._bytes

    def _validate_index(self, index: Int) raises:
        if index < 0 or index >= self._length:
            raise Error("Buffer index is outside the valid range")

    def _validate_range(self, offset: Int, width: Int) raises:
        if offset < 0 or width < 0 or offset > self._length or width > self._length - offset:
            raise Error("Buffer range is outside the valid range")

    def _read_uint(
        self, offset: Float64, width: Int, little_endian: Bool
    ) raises -> UInt64:
        var first = Int(checked_integer(offset, Float64(self._length - width), "offset"))
        var result = UInt64(0)
        for index in range(width):
            var shift = 8 * (index if little_endian else width - index - 1)
            result |= UInt64(
                self._bytes[][self._offset + first + index]
            ) << UInt64(shift)
        return result

    def _read_int(
        self, offset: Float64, width: Int, little_endian: Bool
    ) raises -> Int64:
        var value = self._read_uint(offset, width, little_endian)
        var bits = width * 8
        if bits < 64 and (value & (UInt64(1) << UInt64(bits - 1))):
            return Int64(value) - (Int64(1) << Int64(bits))
        return Int64(value)

    def _write_uint(
        self,
        value: UInt64,
        offset: Float64,
        width: Int,
        little_endian: Bool,
    ) raises:
        var first = Int(checked_integer(offset, Float64(self._length - width), "offset"))
        for index in range(width):
            var shift = 8 * (index if little_endian else width - index - 1)
            self._bytes[][self._offset + first + index] = Byte(
                UInt8((value >> UInt64(shift)) & 0xFF)
            )

    def _write_number(self, value: Float64, offset: Float64, width: Int, little_endian: Bool, signed: Bool) raises:
        var bits = width * 8 - (1 if signed else 0)
        var limit = Int64(1) << bits
        var minimum = -limit if signed else Int64(0)
        if value < Float64(minimum) or value > Float64(limit - 1):
            raise Error("Buffer numeric value is outside the valid range")
        self._write_uint(UInt64(source_number_to_uint32(value)), offset, width, little_endian)

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
