from support.stream_values import require_buffer
from support.stream_events import require_unhandled_stream_error
from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node.event_loop import run_event_loop
from tsonic_node import Buffer, RmOptions, read_text_file, remove_path, write_text_file
from tsonic_node.filesystem.streams import (
    ReadStreamOptions, WriteStreamOptions, create_read_stream, create_write_stream,
)


def main() raises:
    var root = mkdtemp(prefix="tsonic-file-streams-")
    try:
        var source = root + "/input"
        var destination = root + "/output"
        write_text_file(source, "a😀b\0tail")
        var options = ReadStreamOptions()
        options.high_water_mark = 2.0
        var input = create_read_stream(source, options)
        var alias = input
        var output = create_write_stream(destination)
        _ = input.pipe_to(output)
        assert_equal(read_text_file(destination), "")
        run_event_loop()
        assert_equal(read_text_file(destination), "a😀b\0tail")
        assert_equal(alias.bytes_read(), 11.0)
        assert_equal(output.bytes_written(), 11.0)
        assert_false(Bool(alias.read()))
        alias.close()
        output.close()
        assert_equal(input.path(), source)
        assert_equal(output.path(), destination)

        options.start = 5.0
        options.end = 5.0
        input = create_read_stream(source, options)
        assert_equal(require_buffer(input.read()).to_string(), "b")
        assert_false(Bool(input.read()))
        assert_equal(input.bytes_read(), 1.0)

        var writes = WriteStreamOptions()
        writes.flags = String("r+")
        writes.start = 1.0
        writes.flush = True
        write_text_file(destination, "01234")
        output = create_write_stream(destination, writes)
        output.cork()
        assert_true(output.write_string("x"))
        assert_true(output.write_buffer(Buffer.from_string("y")))
        assert_equal(output.bytes_written(), 0.0)
        _ = output.end()
        assert_equal(read_text_file(destination), "0xy34")
        assert_equal(output.bytes_written(), 2.0)
        assert_false(output.write_string("late"))
        require_unhandled_stream_error("Cannot write to an ended")

        writes.flags = String("wx")
        var rejected = False
        try:
            _ = create_write_stream(destination, writes)
        except:
            rejected = True
        assert_true(rejected)
        assert_equal(read_text_file(destination), "0xy34")
        options.start = -1.0
        rejected = False
        try:
            _ = create_read_stream(source, options)
        except:
            rejected = True
        assert_true(rejected)
    finally:
        remove_path(root, RmOptions(recursive=True))
