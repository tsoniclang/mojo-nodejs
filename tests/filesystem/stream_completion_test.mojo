from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_runtime import Location, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_node import Buffer, RmOptions, read_text_file, remove_path, write_text_file
from tsonic_node.filesystem.streams import WriteStreamOptions, create_write_stream
from tsonic_node.internal.callback_queue import Notification
from tsonic_node.stream.completion import has_pending_streams, poll_streams
from tsonic_node.stream.writable import StreamChunk
from tsonic_node.event_loop import run_event_loop


@fieldwise_init
struct Action:
    var trace: Location[String]
    var path: String
    var name: String
    var fail: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Self]()
        assert_equal(read_text_file(action[].path), "éABC")
        action[].trace.write(action[].trace.read() + action[].name)
        if action[].fail:
            raise Error("deliberate callback error")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def notification(trace: Location[String], path: String, name: String, fail: Bool = False) -> Notification:
    var context = allocate_callable_environment(Action(trace, path, name, fail), Action.destroy)
    return Notification(context, Action.invoke)


def encoded_completion(root: String) raises:
    var path = root + "/encoded"
    var trace = Location(String())
    var output = create_write_stream(path)
    var alias = output
    output.cork()
    alias.cork()
    _ = output.write_string_encoded("c3a9", String("hex"), notification(trace, path, "a", True))
    _ = alias.write_buffer_encoded(Buffer.from_string("A"), String("not-an-encoding"), notification(trace, path, "b"))
    assert_false(has_pending_streams())
    assert_false(poll_streams())
    assert_equal(trace.read(), "")
    alias.uncork()
    assert_equal(read_text_file(path), "")
    _ = output.write_value_encoded(StreamChunk(String("Qg==")), String("base64"), notification(trace, path, "c"))
    _ = alias.end_value_encoded(StreamChunk(Buffer.from_string("C")), String("ignored"), notification(trace, path, "z"))
    assert_true(output.writable_ended())
    assert_equal(trace.read(), "")
    assert_equal(read_text_file(path), "éABC")
    var rejected = False
    try:
        _ = poll_streams()
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(trace.read(), "a")
    run_event_loop()
    assert_equal(trace.read(), "abcz")
    assert_false(has_pending_streams())
    _ = output.end_empty_encoded(None, None, notification(trace, path, "r"))
    assert_equal(trace.read(), "abcz")
    run_event_loop()
    assert_equal(trace.read(), "abczr")


def failures_do_not_complete(root: String) raises:
    var path = root + "/failures"
    var trace = Location(String())
    var output = create_write_stream(path)
    var rejected = False
    try:
        _ = output.write_string_encoded("bad", String("unknown"), notification(trace, path, "bad"))
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(read_text_file(path), "")
    assert_true(output.writable())
    assert_false(has_pending_streams())
    _ = output.end()
    write_text_file(path, "unchanged")
    var options = WriteStreamOptions()
    options.flags = String("r")
    output = create_write_stream(path, options)
    output.cork()
    _ = output.write_string_callback("a", notification(trace, path, "never-a"))
    _ = output.write_string_callback("b", notification(trace, path, "never-b"))
    rejected = False
    try:
        _ = output.end_callback(notification(trace, path, "never-finish"))
    except:
        rejected = True
    assert_true(rejected)
    assert_false(has_pending_streams())
    assert_equal(read_text_file(path), "unchanged")
    rejected = False
    try:
        _ = output.end_callback(notification(trace, path, "never-retry"))
    except:
        rejected = True
    assert_true(rejected)
    assert_false(has_pending_streams())
    assert_equal(trace.read(), "")


def main() raises:
    var root = mkdtemp(prefix="tsonic-stream-completion-")
    try:
        encoded_completion(root)
        failures_do_not_complete(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
