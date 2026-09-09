from std.collections import List
from std.utils import Variant
from std.testing import assert_equal, assert_true
from tsonic_node.buffer import Buffer, buffer_concat
from tsonic_node.zlib import ZlibOptions, BrotliOptions, gzip_sync, gzip_sync_options, gunzip_sync, gunzip_sync_options, inflate_sync, deflate_raw_sync_options, inflate_raw_sync_options, brotli_compress_sync_options, brotli_decompress_sync_options, create_unzip, create_brotli_compress, create_brotli_decompress, z_sync_flush, brotli_param_quality, brotli_param_lgwin
from tsonic_node.zlib.options import BrotliParameters


def main() raises:
    var text = String()
    for _ in range(8192):
        text += "abcd"
    var input = Buffer.from_string(text)
    var compressed = gzip_sync(input)
    var bounded = ZlibOptions(max_output_length=Float64(len(input)), chunk_size=64.0)
    assert_true(gunzip_sync_options(compressed, bounded).equals(input))
    bounded.max_output_length = Float64(len(input) - 1)
    var rejected = False
    try:
        _ = gunzip_sync_options(compressed, bounded)
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    bounded.max_output_length = 0.0
    try:
        _ = gzip_sync_options(input, bounded)
    except:
        rejected = True
    assert_true(rejected)

    var pieces = List[Buffer]()
    pieces.append(gzip_sync(Buffer.from_string("first")))
    pieces.append(gzip_sync(Buffer.from_string("second")))
    assert_equal(gunzip_sync(buffer_concat(pieces)).to_string(), "firstsecond")
    var dictionary = Buffer.from_string("abcdabcd")
    var raw_options = ZlibOptions(dictionary=dictionary, window_bits=15.0)
    var raw = deflate_raw_sync_options(input, raw_options)
    assert_true(inflate_raw_sync_options(raw, raw_options).equals(input))

    var incomplete = compressed.subarray(0, Float64(len(compressed) - 4))
    rejected = False
    try:
        _ = gunzip_sync(incomplete)
    except:
        rejected = True
    assert_true(rejected)
    var partial = ZlibOptions(finish_flush=z_sync_flush())
    assert_true(gunzip_sync_options(incomplete, partial).equals(input))
    var unzip = create_unzip()
    _ = unzip.write(compressed)
    unzip.end()
    assert_true(unzip.read().value().equals(input))

    var parameters = BrotliParameters()
    parameters[brotli_param_quality()] = Variant[Bool, Float64](4.0)
    parameters[brotli_param_lgwin()] = Variant[Bool, Float64](18.0)
    var brotli_options = BrotliOptions()
    brotli_options.params = parameters^
    brotli_options.max_output_length = 128.0
    brotli_options.chunk_size = 64.0
    var brotli = brotli_compress_sync_options(input, brotli_options)
    assert_true(len(brotli) < 128)
    var decode_options = BrotliOptions()
    decode_options.max_output_length = Float64(len(input))
    decode_options.chunk_size = 64.0
    assert_true(brotli_decompress_sync_options(brotli, decode_options).equals(input))
    decode_options.max_output_length = Float64(len(input) - 1)
    rejected = False
    try:
        _ = brotli_decompress_sync_options(brotli, decode_options)
    except:
        rejected = True
    assert_true(rejected)
    var compressor = create_brotli_compress()
    compressor.end_buffer(input)
    var decoder = create_brotli_decompress()
    decoder.end_buffer(compressor.read().value())
    assert_true(decoder.read().value().equals(input))
