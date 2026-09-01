from std.collections import List
from std.memory import ArcPointer
from std.utils import StaticTuple

from .buffer import Buffer


comptime SHA256_CONSTANTS = StaticTuple[UInt32, 64](
    0x428A2F98,
    0x71374491,
    0xB5C0FBCF,
    0xE9B5DBA5,
    0x3956C25B,
    0x59F111F1,
    0x923F82A4,
    0xAB1C5ED5,
    0xD807AA98,
    0x12835B01,
    0x243185BE,
    0x550C7DC3,
    0x72BE5D74,
    0x80DEB1FE,
    0x9BDC06A7,
    0xC19BF174,
    0xE49B69C1,
    0xEFBE4786,
    0x0FC19DC6,
    0x240CA1CC,
    0x2DE92C6F,
    0x4A7484AA,
    0x5CB0A9DC,
    0x76F988DA,
    0x983E5152,
    0xA831C66D,
    0xB00327C8,
    0xBF597FC7,
    0xC6E00BF3,
    0xD5A79147,
    0x06CA6351,
    0x14292967,
    0x27B70A85,
    0x2E1B2138,
    0x4D2C6DFC,
    0x53380D13,
    0x650A7354,
    0x766A0ABB,
    0x81C2C92E,
    0x92722C85,
    0xA2BFE8A1,
    0xA81A664B,
    0xC24B8B70,
    0xC76C51A3,
    0xD192E819,
    0xD6990624,
    0xF40E3585,
    0x106AA070,
    0x19A4C116,
    0x1E376C08,
    0x2748774C,
    0x34B0BCB5,
    0x391C0CB3,
    0x4ED8AA4A,
    0x5B9CCA4F,
    0x682E6FF3,
    0x748F82EE,
    0x78A5636F,
    0x84C87814,
    0x8CC70208,
    0x90BEFFFA,
    0xA4506CEB,
    0xBEF9A3F7,
    0xC67178F2,
)

comptime MD5_CONSTANTS = StaticTuple[UInt32, 64](
    0xD76AA478,
    0xE8C7B756,
    0x242070DB,
    0xC1BDCEEE,
    0xF57C0FAF,
    0x4787C62A,
    0xA8304613,
    0xFD469501,
    0x698098D8,
    0x8B44F7AF,
    0xFFFF5BB1,
    0x895CD7BE,
    0x6B901122,
    0xFD987193,
    0xA679438E,
    0x49B40821,
    0xF61E2562,
    0xC040B340,
    0x265E5A51,
    0xE9B6C7AA,
    0xD62F105D,
    0x02441453,
    0xD8A1E681,
    0xE7D3FBC8,
    0x21E1CDE6,
    0xC33707D6,
    0xF4D50D87,
    0x455A14ED,
    0xA9E3E905,
    0xFCEFA3F8,
    0x676F02D9,
    0x8D2A4C8A,
    0xFFFA3942,
    0x8771F681,
    0x6D9D6122,
    0xFDE5380C,
    0xA4BEEA44,
    0x4BDECFA9,
    0xF6BB4B60,
    0xBEBFBC70,
    0x289B7EC6,
    0xEAA127FA,
    0xD4EF3085,
    0x04881D05,
    0xD9D4D039,
    0xE6DB99E5,
    0x1FA27CF8,
    0xC4AC5665,
    0xF4292244,
    0x432AFF97,
    0xAB9423A7,
    0xFC93A039,
    0x655B59C3,
    0x8F0CCC92,
    0xFFEFF47D,
    0x85845DD1,
    0x6FA87E4F,
    0xFE2CE6E0,
    0xA3014314,
    0x4E0811A1,
    0xF7537E82,
    0xBD3AF235,
    0x2AD7D2BB,
    0xEB86D391,
)

comptime MD5_SHIFTS = StaticTuple[Int, 64](
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
)


struct HashState:
    var algorithm: Int
    var words: List[UInt32]
    var pending: List[Byte]
    var total_bytes: UInt64
    var finalized: Bool

    def __init__(out self, algorithm: Int):
        self.algorithm = algorithm
        self.words = List[UInt32](capacity=8)
        self.words.append(
            UInt32(0x67452301) if algorithm != 1 else UInt32(0x6A09E667)
        )
        self.words.append(
            UInt32(0xEFCDAB89) if algorithm != 1 else UInt32(0xBB67AE85)
        )
        self.words.append(
            UInt32(0x98BADCFE) if algorithm != 1 else UInt32(0x3C6EF372)
        )
        self.words.append(
            UInt32(0x10325476) if algorithm != 1 else UInt32(0xA54FF53A)
        )
        if algorithm == 1:
            self.words.append(UInt32(0x510E527F))
            self.words.append(UInt32(0x9B05688C))
            self.words.append(UInt32(0x1F83D9AB))
            self.words.append(UInt32(0x5BE0CD19))
        elif algorithm == 2:
            self.words.append(UInt32(0xC3D2E1F0))
        self.pending = List[Byte](capacity=64)
        self.total_bytes = 0
        self.finalized = False


struct Hash(ImplicitlyCopyable):
    var _state: ArcPointer[HashState]

    def __init__(out self, algorithm: Int):
        self._state = ArcPointer(HashState(algorithm))

    def update_buffer(self, value: Buffer) raises -> Self:
        self._append(value.copy_bytes())
        return self

    def update_string(self, value: String) raises -> Self:
        var bytes = List[Byte](capacity=value.byte_length())
        for byte in value.as_bytes():
            bytes.append(byte)
        self._append(bytes^)
        return self

    def digest(self, encoding: String) raises -> String:
        if self._state[].finalized:
            raise Error("Hash.digest() may only be called once")
        var result = _finalize(self._state[])
        self._state[].finalized = True
        return Buffer(result^).to_string(encoding)

    def _append(self, bytes: List[Byte]) raises:
        if self._state[].finalized:
            raise Error("Hash.update() cannot be called after digest()")
        self._state[].total_bytes += UInt64(len(bytes))
        for byte in bytes:
            self._state[].pending.append(byte)
            if len(self._state[].pending) == 64:
                var block = self._state[].pending.copy()
                _process_block(self._state[], block, 0)
                self._state[].pending.clear()


def create_hash(algorithm: String) raises -> Hash:
    var normalized = algorithm.lower()
    if normalized == "sha256" or normalized == "sha-256":
        return Hash(1)
    if normalized == "sha1" or normalized == "sha-1":
        return Hash(2)
    if normalized == "md5":
        return Hash(3)
    raise Error("Unsupported hash algorithm: ", algorithm)


def _rotate_left(value: UInt32, shift: Int) -> UInt32:
    return (value << UInt32(shift)) | (value >> UInt32(32 - shift))


def _rotate_right(value: UInt32, shift: Int) -> UInt32:
    return (value >> UInt32(shift)) | (value << UInt32(32 - shift))


def _read_word_be(bytes: List[Byte], offset: Int) -> UInt32:
    return (
        (UInt32(bytes[offset]) << 24)
        | (UInt32(bytes[offset + 1]) << 16)
        | (UInt32(bytes[offset + 2]) << 8)
        | UInt32(bytes[offset + 3])
    )


def _read_word_le(bytes: List[Byte], offset: Int) -> UInt32:
    return (
        UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
    )


def _append_word_be(mut bytes: List[Byte], value: UInt32):
    bytes.append(Byte(UInt8(value >> 24)))
    bytes.append(Byte(UInt8(value >> 16)))
    bytes.append(Byte(UInt8(value >> 8)))
    bytes.append(Byte(UInt8(value)))


def _append_word_le(mut bytes: List[Byte], value: UInt32):
    bytes.append(Byte(UInt8(value)))
    bytes.append(Byte(UInt8(value >> 8)))
    bytes.append(Byte(UInt8(value >> 16)))
    bytes.append(Byte(UInt8(value >> 24)))


def _process_block(mut state: HashState, bytes: List[Byte], offset: Int):
    if state.algorithm == 1:
        _process_sha256(state, bytes, offset)
    elif state.algorithm == 2:
        _process_sha1(state, bytes, offset)
    else:
        _process_md5(state, bytes, offset)


def _process_sha256(mut state: HashState, bytes: List[Byte], offset: Int):
    var schedule = List[UInt32](capacity=64)
    for index in range(16):
        schedule.append(_read_word_be(bytes, offset + index * 4))
    for index in range(16, 64):
        var before_15 = schedule[index - 15]
        var before_2 = schedule[index - 2]
        var small_0 = (
            _rotate_right(before_15, 7)
            ^ _rotate_right(before_15, 18)
            ^ (before_15 >> 3)
        )
        var small_1 = (
            _rotate_right(before_2, 17)
            ^ _rotate_right(before_2, 19)
            ^ (before_2 >> 10)
        )
        schedule.append(
            schedule[index - 16] + small_0 + schedule[index - 7] + small_1
        )

    var a = state.words[0]
    var b = state.words[1]
    var c = state.words[2]
    var d = state.words[3]
    var e = state.words[4]
    var f = state.words[5]
    var g = state.words[6]
    var h = state.words[7]
    for index in range(64):
        var sum_1 = (
            _rotate_right(e, 6) ^ _rotate_right(e, 11) ^ _rotate_right(e, 25)
        )
        var choice = (e & f) ^ ((~e) & g)
        var temporary_1 = (
            h + sum_1 + choice + SHA256_CONSTANTS[index] + schedule[index]
        )
        var sum_0 = (
            _rotate_right(a, 2) ^ _rotate_right(a, 13) ^ _rotate_right(a, 22)
        )
        var majority = (a & b) ^ (a & c) ^ (b & c)
        var temporary_2 = sum_0 + majority
        h = g
        g = f
        f = e
        e = d + temporary_1
        d = c
        c = b
        b = a
        a = temporary_1 + temporary_2
    state.words[0] += a
    state.words[1] += b
    state.words[2] += c
    state.words[3] += d
    state.words[4] += e
    state.words[5] += f
    state.words[6] += g
    state.words[7] += h


def _process_sha1(mut state: HashState, bytes: List[Byte], offset: Int):
    var schedule = List[UInt32](capacity=80)
    for index in range(16):
        schedule.append(_read_word_be(bytes, offset + index * 4))
    for index in range(16, 80):
        schedule.append(
            _rotate_left(
                schedule[index - 3]
                ^ schedule[index - 8]
                ^ schedule[index - 14]
                ^ schedule[index - 16],
                1,
            )
        )
    var a = state.words[0]
    var b = state.words[1]
    var c = state.words[2]
    var d = state.words[3]
    var e = state.words[4]
    for index in range(80):
        var function: UInt32
        var constant: UInt32
        if index < 20:
            function = (b & c) | ((~b) & d)
            constant = 0x5A827999
        elif index < 40:
            function = b ^ c ^ d
            constant = 0x6ED9EBA1
        elif index < 60:
            function = (b & c) | (b & d) | (c & d)
            constant = 0x8F1BBCDC
        else:
            function = b ^ c ^ d
            constant = 0xCA62C1D6
        var temporary = (
            _rotate_left(a, 5) + function + e + constant + schedule[index]
        )
        e = d
        d = c
        c = _rotate_left(b, 30)
        b = a
        a = temporary
    state.words[0] += a
    state.words[1] += b
    state.words[2] += c
    state.words[3] += d
    state.words[4] += e


def _process_md5(mut state: HashState, bytes: List[Byte], offset: Int):
    var words = List[UInt32](capacity=16)
    for index in range(16):
        words.append(_read_word_le(bytes, offset + index * 4))
    var a = state.words[0]
    var b = state.words[1]
    var c = state.words[2]
    var d = state.words[3]
    for index in range(64):
        var function: UInt32
        var word_index: Int
        if index < 16:
            function = (b & c) | ((~b) & d)
            word_index = index
        elif index < 32:
            function = (d & b) | ((~d) & c)
            word_index = (5 * index + 1) % 16
        elif index < 48:
            function = b ^ c ^ d
            word_index = (3 * index + 5) % 16
        else:
            function = c ^ (b | (~d))
            word_index = (7 * index) % 16
        var previous_d = d
        d = c
        c = b
        b = b + _rotate_left(
            a + function + MD5_CONSTANTS[index] + words[word_index],
            MD5_SHIFTS[index],
        )
        a = previous_d
    state.words[0] += a
    state.words[1] += b
    state.words[2] += c
    state.words[3] += d


def _finalize(mut state: HashState) -> List[Byte]:
    var tail = state.pending.copy()
    tail.append(Byte(0x80))
    while len(tail) % 64 != 56:
        tail.append(Byte(0))
    var bit_length = state.total_bytes * 8
    if state.algorithm == 3:
        for shift in range(0, 64, 8):
            tail.append(Byte(UInt8(bit_length >> UInt64(shift))))
    else:
        for index in range(8):
            tail.append(Byte(UInt8(bit_length >> UInt64(56 - index * 8))))
    for offset in range(0, len(tail), 64):
        _process_block(state, tail, offset)
    var result = List[Byte]()
    for word in state.words:
        if state.algorithm == 3:
            _append_word_le(result, word)
        else:
            _append_word_be(result, word)
    return result^
