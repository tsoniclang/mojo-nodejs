from std.collections import List
from std.testing import assert_equal, assert_true, assert_false
from tsonic_node.buffer import Buffer, buffer_concat
from tsonic_node.zlib import (
    create_gzip, create_gunzip, create_brotli_compress, create_brotli_decompress,
    gzip_sync, gzip_sync_info_options, gunzip_sync_info_options,
    gzip_sync_result_options, ZlibOptions, ZlibInfo, brotli_operation_flush,
)


def main() raises:
    var first = Buffer.from_string("first")
    var second = Buffer.from_string("second")
    var compressor = create_gzip()
    var decoder = create_gunzip()
    var retained_alias = compressor
    assert_true(compressor.write(first))
    compressor.flush_kind(2.0)
    var prefix = compressor.read()
    assert_true(prefix)
    assert_true(decoder.write(prefix.value()))
    assert_equal(decoder.read().value().to_string(), "first")
    assert_equal(retained_alias.bytes_written(), 5.0)
    compressor.params(1.0, 0.0)
    retained_alias.end_buffer(second)
    assert_true(compressor.closed())
    decoder.end_buffer(compressor.read().value())
    assert_equal(decoder.read().value().to_string(), "second")
    assert_false(decoder.read())
    var rejected = False
    try:
        _ = retained_alias.write(first)
    except:
        rejected = True
    assert_true(rejected)
    compressor.destroy()
    retained_alias.destroy()

    var info = gzip_sync_info_options(first, ZlibOptions(info=True))
    assert_equal(info.engine.bytes_written(), 5.0)
    assert_true(info.engine.closed())
    var chunks = List[Buffer]()
    chunks.append(info.buffer)
    chunks.append(Buffer.allocate(8))
    var padded = buffer_concat(chunks)
    var decoded = gunzip_sync_info_options(padded, ZlibOptions(info=True))
    assert_true(decoded.buffer.equals(first))
    assert_equal(decoded.engine.bytes_written(), Float64(len(info.buffer)))
    var dynamic = gzip_sync_result_options(first, ZlibOptions(info=True))
    assert_true(dynamic.isa[ZlibInfo]())
    dynamic = gzip_sync_result_options(first, ZlibOptions(info=False))
    assert_true(dynamic.isa[Buffer]())

    var resettable = create_gzip()
    _ = resettable.write(first)
    _ = resettable.read()
    resettable.reset()
    assert_equal(resettable.bytes_written(), 0.0)
    resettable.end_buffer(second)
    var reset_decoder = create_gunzip()
    reset_decoder.end_buffer(resettable.read().value())
    assert_equal(reset_decoder.read().value().to_string(), "second")

    var brotli = create_brotli_compress()
    var unbrotli = create_brotli_decompress()
    _ = brotli.write(first)
    brotli.flush_kind(brotli_operation_flush())
    var encoded_prefix = brotli.read()
    assert_true(encoded_prefix)
    _ = unbrotli.write(encoded_prefix.value())
    assert_equal(unbrotli.read().value().to_string(), "first")
    brotli.end_buffer(second)
    unbrotli.end_buffer(brotli.read().value())
    assert_equal(unbrotli.read().value().to_string(), "second")

    var members = create_gunzip()
    var one = gzip_sync(first)
    var two = gzip_sync(second)
    _ = members.write(one)
    assert_equal(members.read().value().to_string(), "first")
    for index in range(len(two)):
        _ = members.write(two.subarray(Float64(index), Float64(index + 1)))
    members.end()
    assert_equal(members.read().value().to_string(), "second")
