from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node.buffer import Buffer, buffer_from_string_encoded
from tsonic_node.filesystem import RmOptions, remove_path, write_text_file, read_text_file
from tsonic_node.filesystem.streams import ReadStreamOptions, create_read_stream, create_write_stream
from tsonic_node.stream import Readable
from tsonic_node.event_loop import run_event_loop
from tsonic_node.stream.decoder import StreamDecoder
from tsonic_node.stream.read_buffer import ReadBuffer
from support.stream_values import require_text, require_buffer


def decoder_boundaries() raises:
    var source = Buffer.from_string("aé😀z")
    for split in range(len(source) + 1):
        var decoder = StreamDecoder("utf8")
        var output = decoder.write(source.subarray(0, Float64(split)))
        output += decoder.write(source.subarray(Float64(split)))
        output += decoder.end()
        assert_equal(output, "aé😀z")
    var bytes = buffer_from_string_encoded("61003dd800de7a00", "hex")
    for split in range(len(bytes) + 1):
        var decoder = StreamDecoder("ucs2")
        var output = decoder.write(bytes.subarray(0, Float64(split)))
        output += decoder.write(bytes.subarray(Float64(split)))
        output += decoder.end()
        assert_equal(output, "a😀z")
    for encoding in ("base64", "base64url"):
        var decoder = StreamDecoder(encoding)
        var output = String()
        for index in range(len(source)):
            output += decoder.write(source.subarray(Float64(index), Float64(index + 1)))
        output += decoder.end()
        assert_equal(output, source.to_string(encoding))
    for encoding in ("ascii", "latin1", "hex"):
        var decoder = StreamDecoder(encoding)
        var output = String()
        for index in range(len(source)):
            output += decoder.write(source.subarray(Float64(index), Float64(index + 1)))
        output += decoder.end()
        assert_equal(output, source.to_string(encoding))


def invalid_and_eof() raises:
    var decoder = StreamDecoder("utf8")
    assert_equal(decoder.write(buffer_from_string_encoded("e282", "hex")), "")
    assert_equal(decoder.end(), "�")
    assert_equal(decoder.end(), "")
    decoder = StreamDecoder("utf8")
    assert_equal(decoder.write(buffer_from_string_encoded("c0af", "hex")), "��")
    decoder = StreamDecoder("utf8")
    assert_equal(decoder.write(buffer_from_string_encoded("e2", "hex")), "")
    assert_equal(decoder.write(Buffer.from_string("a")), "�a")
    decoder = StreamDecoder("utf16le")
    assert_equal(decoder.write(buffer_from_string_encoded("6100ff", "hex")), "a")
    assert_equal(decoder.end(), "")
    decoder = StreamDecoder("utf16le")
    assert_equal(decoder.write(buffer_from_string_encoded("00d8", "hex")), "")
    var rejected = False
    try:
        _ = decoder.end()
    except:
        rejected = True
    assert_true(rejected)


def retained_units() raises:
    var source = Readable()
    source.append(Buffer.from_string("a😀z"))
    var retained_alias = source
    _ = retained_alias.set_encoding("utf8")
    assert_equal(require_text(source.read_sized(1.0)), "a")
    var rejected = False
    try:
        _ = retained_alias.read_sized(1.0)
    except error:
        rejected = "surrogate pair" in String(error)
    assert_true(rejected)
    assert_equal(require_text(source.read_sized(2.0)), "😀")
    assert_equal(require_text(retained_alias.read()), "z")
    assert_false(Bool(source.read()))
    source.append(Buffer.from_string("é"))
    _ = source.set_encoding("hex")
    source.append(Buffer.from_string("A"))
    assert_equal(require_text(retained_alias.read()), "é41")
    var buffer = ReadBuffer()
    buffer.set_encoding("utf8")
    buffer.append(buffer_from_string_encoded("e282", "hex"))
    assert_equal(len(buffer), 0)
    buffer.finish()
    assert_equal(require_text(buffer.take(len(buffer))), "�")
    buffer.finish()
    assert_equal(len(buffer), 0)


def file_decoding(root: String) raises:
    var path = root + "/text"
    write_text_file(path, "😀éZ")
    var options = ReadStreamOptions()
    options.high_water_mark = 1
    options.encoding = "utf8"
    var source = create_read_stream(path, options)
    var retained_alias = source
    assert_equal(require_text(source.read_sized(2.0)), "😀")
    assert_equal(require_text(retained_alias.read_sized(1.0)), "é")
    assert_equal(require_text(source.read_sized(1.0)), "Z")
    assert_false(Bool(source.read()))
    run_event_loop()
    assert_true(source.readable_ended())
    assert_equal(source.bytes_read(), 7)
    source = create_read_stream(path, options)
    var output = create_write_stream(root + "/copy")
    _ = source.pipe_to(output)
    run_event_loop()
    assert_equal(read_text_file(root + "/copy"), "😀éZ")
    options.encoding = None
    source = create_read_stream(path, options)
    var rejected = False
    try:
        _ = source.set_encoding("invalid-encoding")
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(require_buffer(source.read_sized(4.0)).to_string(), "😀")
    source.close()


def main() raises:
    decoder_boundaries()
    invalid_and_eof()
    retained_units()
    var root = mkdtemp(prefix="mojo-stream-decode-")
    try:
        file_decoding(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
