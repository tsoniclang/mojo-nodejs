from std.utils import Variant
from ..buffer import Buffer
from .codec import process
from .options import CodecOptions, ZlibOptions, BrotliOptions, wants_info
from .transform import Zlib


@fieldwise_init
struct ZlibInfo(ImplicitlyCopyable):
    var buffer: Buffer
    var engine: Zlib


comptime ZlibResult = Variant[Buffer, ZlibInfo]


def process_buffer(
    input: Buffer, mode: Int32, options: CodecOptions
) raises -> Buffer:
    if wants_info(options):
        raise Error("Compression info requires the engine/result contract")
    return process(input, mode, options)


def process_info(
    input: Buffer, mode: Int32, options: CodecOptions
) raises -> ZlibInfo:
    if not wants_info(options):
        raise Error("Compression info result requires info: true")
    var engine = Zlib(mode, options.unsafe_get[ZlibOptions]()) if options.isa[
        ZlibOptions
    ]() else Zlib(mode, options.unsafe_get[BrotliOptions]())
    engine.end_buffer(input)
    var output = engine.read()
    return ZlibInfo(output.value() if output else Buffer(), engine)


def process_result(
    input: Buffer, mode: Int32, options: CodecOptions
) raises -> ZlibResult:
    if wants_info(options):
        return ZlibResult(process_info(input, mode, options))
    return ZlibResult(process_buffer(input, mode, options))
