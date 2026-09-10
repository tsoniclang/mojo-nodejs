from std.collections import Dict
from std.utils import Variant
from ..buffer import Buffer
from ..validation import checked_integer


comptime BrotliParameters = Dict[Float64, Variant[Bool, Float64]]
comptime MAX_OUTPUT = 268_435_456
comptime UNSET = Int32(-2147483648)


struct ZlibOptions(ImplicitlyCopyable):
    var flush: Optional[Float64]
    var finish_flush: Optional[Float64]
    var chunk_size: Optional[Float64]
    var window_bits: Optional[Float64]
    var level: Optional[Float64]
    var mem_level: Optional[Float64]
    var strategy: Optional[Float64]
    var max_output_length: Optional[Float64]
    var dictionary: Optional[Buffer]
    var info: Optional[Bool]

    def __init__(
        out self,
        flush: Optional[Float64] = None,
        finish_flush: Optional[Float64] = None,
        chunk_size: Optional[Float64] = None,
        window_bits: Optional[Float64] = None,
        level: Optional[Float64] = None,
        mem_level: Optional[Float64] = None,
        strategy: Optional[Float64] = None,
        max_output_length: Optional[Float64] = None,
        dictionary: Optional[Buffer] = None,
        info: Optional[Bool] = None,
    ):
        self.flush = flush
        self.finish_flush = finish_flush
        self.chunk_size = chunk_size
        self.window_bits = window_bits
        self.level = level
        self.mem_level = mem_level
        self.strategy = strategy
        self.max_output_length = max_output_length
        self.dictionary = dictionary
        self.info = info

    def info_value(self) -> Bool:
        return self.info.value() if self.info else False


@fieldwise_init
struct BrotliOptions(Copyable):
    var flush: Optional[Float64]
    var finish_flush: Optional[Float64]
    var chunk_size: Optional[Float64]
    var max_output_length: Optional[Float64]
    var params: Optional[BrotliParameters]
    var info: Optional[Bool]

    def __init__(out self):
        self.flush = None
        self.finish_flush = None
        self.chunk_size = None
        self.max_output_length = None
        self.params = None
        self.info = None

    def info_value(self) -> Bool:
        return self.info.value() if self.info else False


comptime CodecOptions = Variant[ZlibOptions, BrotliOptions]


def optional_integer(value: Optional[Float64]) raises -> Int32:
    if not value:
        return UNSET
    var number = value.value()
    if not (number >= -2147483647 and number <= 2147483647):
        raise Error("Compression option must be a finite 32-bit integer")
    var result = Int32(number)
    if Float64(result) != number:
        raise Error("Compression option must be an integer")
    return result


def output_limit(value: Optional[Float64]) raises -> Int:
    var result = Int(
        checked_integer(value.value(), Float64(MAX_OUTPUT), "maxOutputLength")
    ) if value else MAX_OUTPUT
    if result == 0:
        raise Error("maxOutputLength must be positive")
    return result


def chunk_size(value: Optional[Float64]) raises -> Int:
    var result = Int(
        checked_integer(value.value(), Float64(MAX_OUTPUT), "chunkSize")
    ) if value else 16384
    if result < 64:
        raise Error("chunkSize must be at least 64")
    return result


def validate_flush(value: Optional[Float64], maximum: Int) raises:
    if value:
        _ = checked_integer(value.value(), Float64(maximum), "flush")


def finish_flush(options: CodecOptions) -> Int32:
    if options.isa[ZlibOptions]():
        var value = options.unsafe_get[ZlibOptions]().finish_flush
        return Int32(value.value()) if value else 4
    var value = options.unsafe_get[BrotliOptions]().finish_flush
    return Int32(value.value()) if value else 2


def write_flush(options: CodecOptions) -> Int32:
    if options.isa[ZlibOptions]():
        var value = options.unsafe_get[ZlibOptions]().flush
        return Int32(value.value()) if value else 0
    var value = options.unsafe_get[BrotliOptions]().flush
    return Int32(value.value()) if value else 0


def wants_info(options: CodecOptions) -> Bool:
    if options.isa[ZlibOptions]():
        return options.unsafe_get[ZlibOptions]().info_value()
    return options.unsafe_get[BrotliOptions]().info_value()
