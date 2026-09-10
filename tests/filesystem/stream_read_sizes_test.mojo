from support.stream_values import require_buffer
from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node import Buffer, RmOptions, remove_path, write_text_file
from tsonic_node.filesystem.streams import ReadStreamOptions, create_read_stream
from tsonic_node.stream import Readable
from tsonic_node.stream.completion import poll_streams
from tsonic_node.stream.read_size import (
    requested_read_size,
    increased_read_threshold,
)


def retained_bytes() raises:
    var source = Readable()
    var bytes = Buffer.from_string("abcdef")
    source.append(bytes)
    var retained_alias = source
    assert_false(Bool(retained_alias.read_sized(0.0)))
    var first = require_buffer(source.read_sized(2.0))
    assert_equal(first.to_string(), "ab")
    assert_true(first.same_storage(bytes))
    bytes.set(2, 67)
    assert_equal(
        require_buffer(retained_alias.read_sized(1.0)).to_string(), "C"
    )
    source.append(Buffer.from_string("ghi"))
    var crossed = require_buffer(retained_alias.read_sized(5.0))
    assert_equal(crossed.to_string(), "defgh")
    assert_false(crossed.same_storage(bytes))
    assert_false(Bool(source.read_sized(3.0)))
    source.append(Buffer.from_string("jk"))
    assert_equal(
        require_buffer(retained_alias.read_sized(3.0)).to_string(), "ijk"
    )
    source.append(Buffer.from_string("one"))
    source.append(Buffer.from_string("two"))
    assert_equal(require_buffer(retained_alias.read()).to_string(), "onetwo")
    assert_false(Bool(source.read()))
    assert_false(source.readable_ended())


def numeric_sizes() raises:
    assert_equal(requested_read_size(1.9).value(), 1)
    assert_equal(requested_read_size(0.0000001).value(), 1)
    assert_equal(requested_read_size(-0.9).value(), 0)
    assert_equal(requested_read_size(-1.0e100).value(), -1.0e100)
    assert_false(Bool(requested_read_size(Float64(FloatLiteral.nan))))
    assert_false(Bool(requested_read_size(Float64(FloatLiteral.infinity))))
    assert_equal(increased_read_threshold(5, 2), 8)
    assert_equal(increased_read_threshold(2, 8), 8)
    var source = Readable()
    source.append(Buffer.from_string("abcdef"))
    assert_false(Bool(source.read_sized(-1.0e100)))
    assert_equal(require_buffer(source.read_sized(1.9)).to_string(), "a")
    var rejected = False
    try:
        _ = source.read_sized(1.0e100)
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(require_buffer(source.read_sized(0.0000001)).to_string(), "b")
    assert_equal(
        require_buffer(
            source.read_sized(Float64(FloatLiteral.infinity))
        ).to_string(),
        "cdef",
    )


def file_sizes(root: String) raises:
    var path = root + "/sized"
    write_text_file(path, "abcdefgh")
    var options = ReadStreamOptions()
    options.high_water_mark = Float64(2)
    var source = create_read_stream(path, options)
    var retained_alias = source
    assert_equal(require_buffer(source.read_sized(3.0)).to_string(), "abc")
    assert_equal(source.bytes_read(), 4)
    assert_equal(
        require_buffer(retained_alias.read_sized(3.0)).to_string(), "def"
    )
    assert_equal(source.bytes_read(), 8)
    assert_equal(require_buffer(source.read_sized(3.0)).to_string(), "gh")
    assert_false(Bool(retained_alias.read_sized(3.0)))
    assert_false(source.readable_ended())
    _ = poll_streams()
    assert_true(source.readable_ended())
    assert_false(source.readable())
    options.start = 2.0
    options.end = 6.0
    source = create_read_stream(path, options)
    assert_equal(require_buffer(source.read_sized(3.0)).to_string(), "cde")
    assert_equal(require_buffer(source.read_sized(3.0)).to_string(), "fg")
    assert_false(Bool(source.read()))
    assert_equal(source.bytes_read(), 5)
    _ = poll_streams()
    assert_true(source.readable_ended())
    options = ReadStreamOptions()
    options.high_water_mark = Float64(0)
    source = create_read_stream(path, options)
    assert_false(Bool(source.read_sized(0.0)))
    assert_false(source.readable_ended())
    assert_equal(source.bytes_read(), 0)
    assert_equal(require_buffer(source.read_sized(1.0)).to_string(), "a")
    source.close()


def main() raises:
    retained_bytes()
    numeric_sizes()
    var root = mkdtemp(prefix="tsonic-stream-read-size-")
    try:
        file_sizes(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
