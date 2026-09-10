from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer

from .buffer import Buffer


struct _DigestState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var finished: Bool

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle
        self.finished = False

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_digest_free", NoneType](
                self.handle.value()
            )


struct _Digest(ImplicitlyCopyable):
    var state: ArcPointer[_DigestState]

    def __init__(out self, state: ArcPointer[_DigestState]):
        self.state = state

    def duplicate(self) raises -> Self:
        if self.state[].finished:
            raise Error("Cannot copy a finalized digest")
        var handle = external_call[
            "tsonic_node_digest_copy",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](self.state[].handle.value())
        if not handle:
            raise Error("Unable to copy digest")
        return Self(ArcPointer(_DigestState(handle)))

    def __init__(
        out self, var algorithm: String, key: Buffer, keyed: Bool
    ) raises:
        if algorithm.find("\0") != -1:
            raise Error("A digest algorithm cannot contain a null byte")
        var bytes = key.copy_bytes()
        var handle = external_call[
            "tsonic_node_digest_create",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](
            algorithm.as_c_string_slice(),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            c_int(keyed),
        )
        if not handle:
            raise Error("Unable to initialize digest algorithm: ", algorithm)
        self.state = ArcPointer(_DigestState(handle))

    def update(self, value: Buffer) raises:
        if self.state[].finished:
            raise Error("Cannot update a finalized digest")
        var bytes = value.copy_bytes()
        if (
            external_call["tsonic_node_digest_update", c_int](
                self.state[].handle.value(),
                bytes.unsafe_ptr(),
                c_size_t(len(bytes)),
            )
            != 1
        ):
            self.state[].finished = True
            raise Error("Unable to update digest")

    def finish(self) raises -> Buffer:
        if self.state[].finished:
            raise Error("Hash.digest() may only be called once")
        self.state[].finished = True
        var size = Int(
            external_call["tsonic_node_digest_size", c_size_t](
                self.state[].handle.value()
            )
        )
        var bytes = List[Byte](capacity=size)
        for _ in range(size):
            bytes.append(0)
        if (
            external_call["tsonic_node_digest_finish", c_int](
                self.state[].handle.value(), bytes.unsafe_ptr(), c_size_t(size)
            )
            != 1
        ):
            raise Error("Unable to finalize digest")
        return Buffer(bytes^)


struct Hash(ImplicitlyCopyable):
    var _digest: _Digest

    def __init__(out self, algorithm: String) raises:
        self._digest = _Digest(algorithm, Buffer(), False)

    def __init__(out self, digest: _Digest):
        self._digest = digest

    def copy_hash(self) raises -> Self:
        return Self(self._digest.duplicate())

    def update_buffer(self, value: Buffer) raises -> Self:
        self._digest.update(value)
        return self

    def update_string(self, value: String) raises -> Self:
        return self.update_buffer(Buffer.from_string(value))

    def digest(self) raises -> Buffer:
        return self._digest.finish()

    def digest(self, encoding: String) raises -> String:
        return self.digest().to_string(encoding)


struct Hmac(ImplicitlyCopyable):
    var _digest: _Digest

    def __init__(out self, algorithm: String, key: Buffer) raises:
        self._digest = _Digest(algorithm, key, True)

    def update_buffer(self, value: Buffer) raises -> Self:
        self._digest.update(value)
        return self

    def update_string(self, value: String) raises -> Self:
        return self.update_buffer(Buffer.from_string(value))

    def digest(self) raises -> Buffer:
        if self._digest.state[].finished:
            return Buffer()
        return self._digest.finish()

    def digest(self, encoding: String) raises -> String:
        return self.digest().to_string(encoding)


def create_hash(algorithm: String) raises -> Hash:
    return Hash(algorithm)


def create_hmac(algorithm: String, key: String) raises -> Hmac:
    return Hmac(algorithm, Buffer.from_string(key))


def create_hmac(algorithm: String, key: Buffer) raises -> Hmac:
    return Hmac(algorithm, key)


def random_bytes(size: Float64) raises -> Buffer:
    if size != size or size < 0 or size > 2147483647:
        raise Error("Random byte count must be between 0 and 2147483647")
    var length = Int(size)
    var bytes = List[Byte](capacity=length)
    for _ in range(length):
        bytes.append(0)
    if (
        external_call["tsonic_node_random_bytes", c_int](
            bytes.unsafe_ptr(), c_size_t(length)
        )
        != 1
    ):
        raise Error("Unable to obtain cryptographically secure random bytes")
    return Buffer(bytes^)


def random_fill(mut buffer: Buffer) raises -> Buffer:
    var bytes = random_bytes(Float64(len(buffer)))
    for index in range(len(buffer)):
        buffer.set(index, bytes.get(index))
    return buffer


def timing_safe_equal(left: Buffer, right: Buffer) raises -> Bool:
    if len(left) != len(right):
        raise Error("Input buffers must have the same byte length")
    var left_bytes = left.copy_bytes()
    var right_bytes = right.copy_bytes()
    return (
        external_call["tsonic_node_timing_safe_equal", c_int](
            left_bytes.unsafe_ptr(),
            right_bytes.unsafe_ptr(),
            c_size_t(len(left_bytes)),
        )
        != 0
    )


def random_int(maximum: Float64) raises -> Float64:
    return random_int(0, maximum)


def random_int(minimum: Float64, maximum: Float64) raises -> Float64:
    if not (
        minimum >= -9007199254740991.0
        and maximum <= 9007199254740991.0
        and maximum > minimum
    ):
        raise Error("Random integer bounds must be ordered safe integers")
    var first = Int64(minimum)
    var last = Int64(maximum)
    if Float64(first) != minimum or Float64(last) != maximum:
        raise Error("Random integer bounds must be integers")
    var width = UInt64(last - first)
    if width >= (UInt64(1) << 48):
        raise Error("Random integer range must be smaller than 2**48")
    var highest = ~UInt64(0)
    var limit = highest - highest % width
    while True:
        var value = UInt64(0)
        if (
            external_call["tsonic_node_random_bytes", c_int](
                Pointer(to=value), c_size_t(8)
            )
            != 1
        ):
            raise Error(
                "Unable to obtain cryptographically secure random bytes"
            )
        if value < limit:
            return Float64(first + Int64(value % width))


def random_uuid() raises -> String:
    var bytes = random_bytes(16)
    bytes.set(6, (bytes.get(6) & 0x0F) | 0x40)
    bytes.set(8, (bytes.get(8) & 0x3F) | 0x80)
    var hex = bytes.to_string("hex")
    return (
        hex[byte=0:8]
        + "-"
        + hex[byte=8:12]
        + "-"
        + hex[byte=12:16]
        + "-"
        + hex[byte=16:20]
        + "-"
        + hex[byte=20:32]
    )
