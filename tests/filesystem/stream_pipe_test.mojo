from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from std.time import monotonic, sleep
from tsonic_runtime import WeakReferenceIdentity
from support.stream_events import require_unhandled_stream_error
from tsonic_node.buffer import Buffer
from tsonic_node.filesystem import RmOptions, read_text_file, remove_path, write_text_file
from tsonic_node.filesystem.streams import ReadStreamOptions, WriteStreamOptions, create_read_stream, create_write_stream
from tsonic_node.stream import Readable, stdout, stderr
from tsonic_node.stream.readable import has_active_readables, poll_readables
from tsonic_node.stream.completion import has_pending_streams, poll_streams


def drain_pipes() raises:
    var deadline = monotonic() + 10000000000
    while has_active_readables() or has_pending_streams():
        assert_true(monotonic() < deadline)
        _ = poll_streams()
        _ = poll_readables()
        sleep(0.001)


def deferred_and_shared(root: String) raises:
    write_text_file(root + "/input", "a😀b")
    var options = ReadStreamOptions()
    options.high_water_mark = Float64(1)
    options.encoding = "utf8"
    var source = create_read_stream(root + "/input", options)
    var retained_alias = source
    var first = create_write_stream(root + "/first")
    var second = create_write_stream(root + "/second")
    var returned = source.pipe_to(first)
    _ = retained_alias.pipe_to(second)
    assert_equal(source.bytes_read(), 0.0)
    assert_equal(first.bytes_written(), 0.0)
    assert_false(returned.writable_ended())
    _ = source.pause()
    _ = poll_readables()
    for _ in range(10):
        assert_false(poll_readables())
    assert_equal(source.bytes_read(), 0.0)
    _ = retained_alias.resume()
    drain_pipes()
    assert_equal(read_text_file(root + "/first"), "a😀b")
    assert_equal(read_text_file(root + "/second"), "a😀b")
    assert_equal(first.bytes_written(), 6.0)
    assert_equal(second.bytes_written(), 6.0)
    assert_true(returned.writable_ended())


def pending_is_not_eof(root: String) raises:
    var source = Readable()
    var output = create_write_stream(root + "/pending")
    _ = source.pipe_to(output)
    _ = poll_readables()
    assert_equal(output.bytes_written(), 0)
    assert_true(output.writable())
    source.append(Buffer.from_string("later"))
    assert_true(poll_readables())
    assert_equal(read_text_file(root + "/pending"), "later")
    assert_true(output.writable())
    source._accept_read(None)
    drain_pipes()
    assert_true(output.writable_ended())
    source = Readable()
    output = create_write_stream(root + "/closed")
    _ = source.pipe_to(output)
    source.close()
    drain_pipes()
    assert_true(output.writable())
    _ = output.end()


def pressure_and_release(root: String) raises:
    write_text_file(root + "/pressure-input", "abcdefgh")
    var options = ReadStreamOptions()
    options.high_water_mark = Float64(2)
    var source = create_read_stream(root + "/pressure-input", options)
    var write_options = WriteStreamOptions()
    write_options.high_water_mark = Float64(1)
    var output = create_write_stream(root + "/pressure-output", write_options)
    output.cork()
    _ = source.pipe_to(output)
    var deadline = monotonic() + 10000000000
    while source.bytes_read() == 0:
        assert_true(monotonic() < deadline)
        _ = poll_readables()
        sleep(0.001)
    var accepted = source.bytes_read()
    assert_equal(accepted, 2.0)
    for _ in range(10):
        assert_false(poll_readables())
    assert_equal(source.bytes_read(), accepted)
    assert_equal(read_text_file(root + "/pressure-output"), "")
    output.uncork()
    drain_pipes()
    assert_equal(read_text_file(root + "/pressure-output"), "abcdefgh")


def independent_errors(root: String) raises:
    write_text_file(root + "/read-only", "untouched")
    var bad_source = Readable()
    bad_source.append(Buffer.from_string("invalid"))
    var write_options = WriteStreamOptions()
    write_options.flags = "r"
    var invalid = create_write_stream(root + "/read-only", write_options)
    _ = bad_source.pipe_to(invalid)
    var good_source = Readable()
    good_source.append(Buffer.from_string("retained"))
    good_source._accept_read(None)
    var output = create_write_stream(root + "/good")
    _ = good_source.pipe_to(output)
    _ = poll_readables()
    require_unhandled_stream_error("Unable to write stream")
    assert_true(has_active_readables())
    drain_pipes()
    assert_equal(read_text_file(root + "/good"), "retained")
    assert_equal(read_text_file(root + "/read-only"), "untouched")


def standard_output_does_not_end() raises:
    var source = Readable()
    source._accept_read(None)
    var output = stdout()
    var error_output = stderr()
    _ = source.pipe_to(output)
    _ = source.pipe_to(error_output)
    drain_pipes()
    assert_true(output.writable())
    assert_true(error_output.writable())
    assert_false(output.writable_ended())
    assert_false(error_output.writable_ended())
    assert_equal(len(source._state[].pipes), 0)
    assert_false(source._state[].events.state[].data.has_listeners())


def retained_ended_source(root: String) raises -> Tuple[Readable, WeakReferenceIdentity]:
    var source = Readable()
    source.append(Buffer.from_string("finished"))
    source._accept_read(None)
    var output = create_write_stream(root + "/released-destination")
    var identity = WeakReferenceIdentity(output._state)
    _ = source.pipe_to(output)
    assert_true(identity.is_alive())
    drain_pipes()
    assert_true(output.writable_ended())
    assert_equal(len(source._state[].pipes), 0)
    assert_false(source._state[].events.state[].data.has_listeners())
    assert_equal(read_text_file(root + "/released-destination"), "finished")
    return (source, identity)


def retained_paused_source(root: String) raises -> Tuple[Readable, WeakReferenceIdentity]:
    var source = Readable()
    var output = create_write_stream(root + "/closed-destination")
    var identity = WeakReferenceIdentity(output._state)
    _ = source.pipe_to(output)
    _ = source.pause()
    output.close()
    drain_pipes()
    assert_false(has_active_readables())
    assert_equal(len(source._state[].pipes), 0)
    assert_false(source._state[].events.state[].data.has_listeners())
    return (source, identity)


def destination_lifetimes(root: String) raises:
    var ended = retained_ended_source(root)
    assert_true(ended[0].readable_ended())
    assert_false(ended[1].is_alive())
    var paused = retained_paused_source(root)
    assert_true(paused[0].is_paused())
    assert_false(paused[1].is_alive())
    var source = Readable()
    var output = create_write_stream(root + "/early-close")
    _ = source.pipe_to(output)
    source.close()
    drain_pipes()
    assert_true(output.writable())
    assert_equal(len(source._state[].pipes), 0)
    assert_false(source._state[].events.state[].data.has_listeners())
    _ = output.end()
    drain_pipes()


def main() raises:
    var root = mkdtemp(prefix="mojo-stream-pipe-")
    try:
        deferred_and_shared(root)
        pending_is_not_eof(root)
        pressure_and_release(root)
        independent_errors(root)
        standard_output_does_not_end()
        destination_lifetimes(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
