from ..buffer import Buffer
from .options import ZlibOptions, BrotliOptions, CodecOptions
from .codec import process
from .results import ZlibInfo, ZlibResult, process_info, process_result
from .callbacks import (
    ZlibCallback,
    ZlibInfoCallback,
    ZlibResultCallback,
    enqueue,
    enqueue_info,
    enqueue_result,
)
from .transform import Zlib

comptime _GZIP = Int32(3)
comptime _GUNZIP = Int32(4)
comptime _DEFLATE = Int32(1)
comptime _INFLATE = Int32(2)
comptime _DEFLATE_RAW = Int32(5)
comptime _INFLATE_RAW = Int32(6)
comptime _UNZIP = Int32(7)
comptime _BROTLI_COMPRESS = Int32(8)
comptime _BROTLI_DECOMPRESS = Int32(9)


def gzip_sync(input: Buffer) raises -> Buffer:
    return process(input, _GZIP, ZlibOptions())


def gzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return process(input, _GZIP, options)


def gzip_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _GZIP, CodecOptions(options))


def gzip_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _GZIP, CodecOptions(options))


def gzip_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _GZIP, ZlibOptions(), callback)


def gzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _GZIP, options, callback)


def gzip_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _GZIP, CodecOptions(options), callback)


def gzip_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _GZIP, CodecOptions(options), callback)


def create_gzip() raises -> Zlib:
    return Zlib(_GZIP, ZlibOptions())


def create_gzip_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_GZIP, options)


def gunzip_sync(input: Buffer) raises -> Buffer:
    return process(input, _GUNZIP, ZlibOptions())


def gunzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return process(input, _GUNZIP, options)


def gunzip_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _GUNZIP, CodecOptions(options))


def gunzip_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _GUNZIP, CodecOptions(options))


def gunzip_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _GUNZIP, ZlibOptions(), callback)


def gunzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _GUNZIP, options, callback)


def gunzip_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _GUNZIP, CodecOptions(options), callback)


def gunzip_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _GUNZIP, CodecOptions(options), callback)


def create_gunzip() raises -> Zlib:
    return Zlib(_GUNZIP, ZlibOptions())


def create_gunzip_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_GUNZIP, options)


def deflate_sync(input: Buffer) raises -> Buffer:
    return process(input, _DEFLATE, ZlibOptions())


def deflate_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return process(input, _DEFLATE, options)


def deflate_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _DEFLATE, CodecOptions(options))


def deflate_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _DEFLATE, CodecOptions(options))


def deflate_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _DEFLATE, ZlibOptions(), callback)


def deflate_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _DEFLATE, options, callback)


def deflate_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _DEFLATE, CodecOptions(options), callback)


def deflate_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _DEFLATE, CodecOptions(options), callback)


def create_deflate() raises -> Zlib:
    return Zlib(_DEFLATE, ZlibOptions())


def create_deflate_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_DEFLATE, options)


def inflate_sync(input: Buffer) raises -> Buffer:
    return process(input, _INFLATE, ZlibOptions())


def inflate_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return process(input, _INFLATE, options)


def inflate_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _INFLATE, CodecOptions(options))


def inflate_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _INFLATE, CodecOptions(options))


def inflate_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _INFLATE, ZlibOptions(), callback)


def inflate_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _INFLATE, options, callback)


def inflate_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _INFLATE, CodecOptions(options), callback)


def inflate_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _INFLATE, CodecOptions(options), callback)


def create_inflate() raises -> Zlib:
    return Zlib(_INFLATE, ZlibOptions())


def create_inflate_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_INFLATE, options)


def deflate_raw_sync(input: Buffer) raises -> Buffer:
    return process(input, _DEFLATE_RAW, ZlibOptions())


def deflate_raw_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return process(input, _DEFLATE_RAW, options)


def deflate_raw_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _DEFLATE_RAW, CodecOptions(options))


def deflate_raw_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _DEFLATE_RAW, CodecOptions(options))


def deflate_raw_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _DEFLATE_RAW, ZlibOptions(), callback)


def deflate_raw_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _DEFLATE_RAW, options, callback)


def deflate_raw_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _DEFLATE_RAW, CodecOptions(options), callback)


def deflate_raw_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _DEFLATE_RAW, CodecOptions(options), callback)


def create_deflate_raw() raises -> Zlib:
    return Zlib(_DEFLATE_RAW, ZlibOptions())


def create_deflate_raw_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_DEFLATE_RAW, options)


def inflate_raw_sync(input: Buffer) raises -> Buffer:
    return process(input, _INFLATE_RAW, ZlibOptions())


def inflate_raw_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return process(input, _INFLATE_RAW, options)


def inflate_raw_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _INFLATE_RAW, CodecOptions(options))


def inflate_raw_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _INFLATE_RAW, CodecOptions(options))


def inflate_raw_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _INFLATE_RAW, ZlibOptions(), callback)


def inflate_raw_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _INFLATE_RAW, options, callback)


def inflate_raw_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _INFLATE_RAW, CodecOptions(options), callback)


def inflate_raw_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _INFLATE_RAW, CodecOptions(options), callback)


def create_inflate_raw() raises -> Zlib:
    return Zlib(_INFLATE_RAW, ZlibOptions())


def create_inflate_raw_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_INFLATE_RAW, options)


def unzip_sync(input: Buffer) raises -> Buffer:
    return process(input, _UNZIP, ZlibOptions())


def unzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return process(input, _UNZIP, options)


def unzip_sync_info_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibInfo:
    return process_info(input, _UNZIP, CodecOptions(options))


def unzip_sync_result_options(
    input: Buffer, options: ZlibOptions
) raises -> ZlibResult:
    return process_result(input, _UNZIP, CodecOptions(options))


def unzip_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _UNZIP, ZlibOptions(), callback)


def unzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    enqueue(input, _UNZIP, options, callback)


def unzip_callback_info_options(
    input: Buffer, options: ZlibOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(input, _UNZIP, CodecOptions(options), callback)


def unzip_callback_result_options(
    input: Buffer, options: ZlibOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(input, _UNZIP, CodecOptions(options), callback)


def create_unzip() raises -> Zlib:
    return Zlib(_UNZIP, ZlibOptions())


def create_unzip_options(options: ZlibOptions) raises -> Zlib:
    return Zlib(_UNZIP, options)


def brotli_compress_sync(input: Buffer) raises -> Buffer:
    return process(input, _BROTLI_COMPRESS, BrotliOptions())


def brotli_compress_sync_options(
    input: Buffer, options: BrotliOptions
) raises -> Buffer:
    return process(input, _BROTLI_COMPRESS, options)


def brotli_compress_sync_info_options(
    input: Buffer, options: BrotliOptions
) raises -> ZlibInfo:
    return process_info(input, _BROTLI_COMPRESS, CodecOptions(options.copy()))


def brotli_compress_sync_result_options(
    input: Buffer, options: BrotliOptions
) raises -> ZlibResult:
    return process_result(input, _BROTLI_COMPRESS, CodecOptions(options.copy()))


def brotli_compress_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _BROTLI_COMPRESS, BrotliOptions(), callback)


def brotli_compress_callback_options(
    input: Buffer, options: BrotliOptions, callback: ZlibCallback
) raises:
    enqueue(input, _BROTLI_COMPRESS, options, callback)


def brotli_compress_callback_info_options(
    input: Buffer, options: BrotliOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(
        input, _BROTLI_COMPRESS, CodecOptions(options.copy()), callback
    )


def brotli_compress_callback_result_options(
    input: Buffer, options: BrotliOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(
        input, _BROTLI_COMPRESS, CodecOptions(options.copy()), callback
    )


def create_brotli_compress() raises -> Zlib:
    return Zlib(_BROTLI_COMPRESS, BrotliOptions())


def create_brotli_compress_options(options: BrotliOptions) raises -> Zlib:
    return Zlib(_BROTLI_COMPRESS, options)


def brotli_decompress_sync(input: Buffer) raises -> Buffer:
    return process(input, _BROTLI_DECOMPRESS, BrotliOptions())


def brotli_decompress_sync_options(
    input: Buffer, options: BrotliOptions
) raises -> Buffer:
    return process(input, _BROTLI_DECOMPRESS, options)


def brotli_decompress_sync_info_options(
    input: Buffer, options: BrotliOptions
) raises -> ZlibInfo:
    return process_info(input, _BROTLI_DECOMPRESS, CodecOptions(options.copy()))


def brotli_decompress_sync_result_options(
    input: Buffer, options: BrotliOptions
) raises -> ZlibResult:
    return process_result(
        input, _BROTLI_DECOMPRESS, CodecOptions(options.copy())
    )


def brotli_decompress_callback(input: Buffer, callback: ZlibCallback) raises:
    enqueue(input, _BROTLI_DECOMPRESS, BrotliOptions(), callback)


def brotli_decompress_callback_options(
    input: Buffer, options: BrotliOptions, callback: ZlibCallback
) raises:
    enqueue(input, _BROTLI_DECOMPRESS, options, callback)


def brotli_decompress_callback_info_options(
    input: Buffer, options: BrotliOptions, callback: ZlibInfoCallback
) raises:
    enqueue_info(
        input, _BROTLI_DECOMPRESS, CodecOptions(options.copy()), callback
    )


def brotli_decompress_callback_result_options(
    input: Buffer, options: BrotliOptions, callback: ZlibResultCallback
) raises:
    enqueue_result(
        input, _BROTLI_DECOMPRESS, CodecOptions(options.copy()), callback
    )


def create_brotli_decompress() raises -> Zlib:
    return Zlib(_BROTLI_DECOMPRESS, BrotliOptions())


def create_brotli_decompress_options(options: BrotliOptions) raises -> Zlib:
    return Zlib(_BROTLI_DECOMPRESS, options)
