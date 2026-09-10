from support.stream_values import require_buffer
from support.stream_events import require_unhandled_stream_error
from tsonic_node.stream.completion import poll_streams
from std.collections import List
from std.math import FloatLiteral
from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node import Buffer, RmOptions, read_text_file, remove_path, write_text_file
from tsonic_node.filesystem.streams import WriteStreamOptions, create_read_stream, create_write_stream
from tsonic_node.stream import Readable


def write_pressure(root: String) raises:
    var path = root + "/pressure"
    var options = WriteStreamOptions()
    options.high_water_mark = 3
    var output = create_write_stream(path, options)
    options.high_water_mark = 9999
    var retained_alias = output
    assert_true(output.writable())
    assert_false(output.writable_ended())
    output.cork()
    retained_alias.cork()
    assert_true(output.write_string("é"))
    assert_false(retained_alias.write_string("a"))
    assert_false(output.write_string(""))
    assert_equal(output._state[].buffered_bytes, 3)
    output.uncork()
    assert_equal(output._state[].buffered_bytes, 3)
    assert_equal(read_text_file(path), "")
    retained_alias.uncork()
    assert_equal(output._state[].buffered_bytes, 0)
    assert_equal(read_text_file(path), "éa")
    assert_true(output.write_string("12345"))
    output.cork()
    _ = output.write_string("c")
    retained_alias.close()
    assert_equal(read_text_file(path), "éa12345c")
    assert_equal(output.bytes_written(), 9)
    assert_false(output.writable())
    assert_true(output.writable_ended())
    assert_equal(output.writable_corked(), 0)
    retained_alias.close()
    assert_false(output.write_string("late"))
    require_unhandled_stream_error("Cannot write to an ended")
    assert_equal(read_text_file(path), "éa12345c")

    options.high_water_mark = 0
    output = create_write_stream(path, options)
    assert_true(output.write_string(""))
    output.cork()
    assert_false(output.write_string("a"))
    output.uncork()
    assert_true(output.write_string("b"))
    _ = output.end()
    assert_equal(read_text_file(path), "ab")


def independent_read_state(root: String) raises:
    var path = root + "/read-state"
    write_text_file(path, "content")
    var input = create_read_stream(path)
    var retained_alias = input
    assert_true(input.readable())
    assert_false(input.readable_ended())
    input.close()
    assert_false(retained_alias.readable())
    assert_false(retained_alias.readable_ended())
    assert_false(Bool(retained_alias.read()))
    input = create_read_stream(path)
    assert_equal(require_buffer(input.read()).to_string(), "content")
    assert_false(input.readable_ended())
    assert_false(Bool(input.read()))
    assert_false(input.readable_ended())
    _ = poll_streams()
    assert_true(input.readable_ended())
    assert_false(input.readable())
    input.close()
    assert_true(input.readable_ended())
    var queued = Readable()
    queued.append(Buffer.from_string("unread"))
    queued.close()
    assert_false(Bool(queued.read()))
    assert_false(queued.readable_ended())


def validation_and_failure(root: String) raises:
    var path = root + "/protected"
    write_text_file(path, "unchanged")
    var options = WriteStreamOptions()
    var invalid_watermarks = List[Float64](capacity=4)
    invalid_watermarks.append(-1.0)
    invalid_watermarks.append(0.5)
    invalid_watermarks.append(Float64(FloatLiteral.nan))
    invalid_watermarks.append(Float64(FloatLiteral.infinity))
    for invalid in invalid_watermarks:
        options.high_water_mark = invalid
        var rejected = False
        try:
            _ = create_write_stream(path, options)
        except:
            rejected = True
        assert_true(rejected)
        assert_equal(read_text_file(path), "unchanged")
    options.high_water_mark = 3
    options.flags = String("r")
    var output = create_write_stream(path, options)
    assert_false(output.write_string("cannot-write"))
    require_unhandled_stream_error("Unable to write stream")
    assert_false(output.writable())
    assert_false(output.writable_ended())
    assert_equal(output.bytes_written(), 0)
    assert_equal(read_text_file(path), "unchanged")


def main() raises:
    var root = mkdtemp(prefix="tsonic-stream-state-")
    try:
        write_pressure(root)
        independent_read_state(root)
        validation_and_failure(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
