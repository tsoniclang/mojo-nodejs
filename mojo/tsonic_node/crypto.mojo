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
