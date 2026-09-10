from support.stream_values import require_buffer
from support.stream_events import require_unhandled_stream_error
from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node import Buffer, RmOptions, read_text_file, remove_path
from tsonic_node.filesystem.streams import WriteStreamOptions, create_write_stream
from tsonic_node.stream import Readable


def queued_reads() raises:
    var stream = Readable()
    var retained = List[Buffer]()
    for index in range(4096):
        var buffer = Buffer.allocate(1, UInt8(index % 251))
        retained.append(buffer)
        stream.append(buffer)
    var alias = stream
    for index in range(4096):
        var value = alias.read_sized(1.0)
        assert_true(Bool(value))
        var buffer = require_buffer(value)
        assert_equal(buffer.get(0), UInt8(index % 251))
        assert_true(buffer.same_storage(retained[index]))
    assert_false(Bool(stream.read()))


def nested_corks(root: String) raises:
    var path = root + "/corked"
    var options = WriteStreamOptions()
    options.flush = True
    var output = create_write_stream(path, options)
    var alias = output
    output.cork()
    alias.cork()
    assert_equal(output.writable_corked(), 2.0)
    _ = output.write_string("first")
    output.uncork()
    assert_equal(alias.writable_corked(), 1.0)
    assert_equal(read_text_file(path), "")
    _ = alias.write_string("second")
    alias.uncork()
    assert_equal(output.writable_corked(), 0.0)
    assert_equal(read_text_file(path), "firstsecond")
    output.uncork()
    assert_equal(output.writable_corked(), 0.0)
    output.cork()
    output.cork()
    _ = output.write_string("third")
    assert_equal(read_text_file(path), "firstsecond")
    _ = output.end()
    assert_equal(output.writable_corked(), 0.0)
    assert_equal(read_text_file(path), "firstsecondthird")
    _ = alias.end()
    assert_equal(read_text_file(path), "firstsecondthird")
    _ = alias.end_string("late")
    require_unhandled_stream_error("Cannot write to an ended")


def main() raises:
    queued_reads()
    var root = mkdtemp(prefix="tsonic-stream-contracts-")
    try:
        nested_corks(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
