from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from std.time import monotonic, sleep
from tsonic_runtime import (
    Location,
    TsError,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.buffer import Buffer
from tsonic_node.filesystem import (
    RmOptions,
    read_text_file,
    remove_path,
    write_text_file,
)
from tsonic_node.filesystem.streams import (
    create_read_stream,
    create_write_stream,
)
from tsonic_node.internal.callback_queue import Notification
from tsonic_node.readline import (
    ReadLineOptions,
    create_interface,
    QuestionCallback,
    has_pending_readline,
)
from tsonic_node.stream import Readable
from tsonic_node.stream.chunk import StreamChunk
from tsonic_node.stream.read_events import DataCallback, ReadErrorCallback
from tsonic_node.stream.readable import has_active_readables, poll_readables
from tsonic_node.stream.completion import has_pending_streams, poll_streams
from support.input_events import poll_input_events
from support.stream_values import require_buffer


@fieldwise_init
struct Action:
    var trace: Location[String]
    var label: String
    var replacement: Int
    var fail: Bool

    @staticmethod
    def data(
        context: ErasedCallableContext, var arguments: Tuple[StreamChunk]
    ) raises:
        var action = context.unsafe_bitcast[Self]()
        var value = arguments[0].copy()
        var text = value.unsafe_get[String]() if value.isa[
            String
        ]() else value.unsafe_get[Buffer]().to_string()
        action[].trace.write(action[].trace.read() + action[].label + text)
        if action[].replacement >= 0:
            assert_true(value.isa[Buffer]())
            value.unsafe_get[Buffer]().set(0, UInt8(action[].replacement))
        if action[].fail:
            raise Error("selected data callback failure")

    @staticmethod
    def empty(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + action[].label)

    @staticmethod
    def error(
        context: ErasedCallableContext, var arguments: Tuple[TsError]
    ) raises:
        var action = context.unsafe_bitcast[Self]()
        assert_true(arguments[0].message.byte_length() != 0)
        action[].trace.write(action[].trace.read() + action[].label)

    @staticmethod
    def answer(
        context: ErasedCallableContext, var arguments: Tuple[String]
    ) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(
            action[].trace.read() + action[].label + arguments[0]
        )


def data(
    trace: Location[String],
    label: String = "",
    replacement: Int = -1,
    fail: Bool = False,
) -> DataCallback:
    var environment = allocate_callable_environment(
        Action(trace, label, replacement, fail),
        destroy_callable_environment[Action],
    )
    return DataCallback(environment, Action.data)


def notification(trace: Location[String], label: String) -> Notification:
    var environment = allocate_callable_environment(
        Action(trace, label, -1, False), destroy_callable_environment[Action]
    )
    return Notification(environment, Action.empty)


def drain() raises:
    var deadline = monotonic() + 10000000000
    while (
        has_active_readables()
        or has_pending_streams()
        or has_pending_readline()
    ):
        assert_true(monotonic() < deadline)
        _ = poll_input_events()
        sleep(0.001)


def manual_and_listener_identity() raises:
    var input = Readable()
    var retained_alias = input
    var trace = Location(String())
    var selected = data(trace, "selected:")
    _ = input.on_data("data", selected)
    _ = retained_alias.on_data("data", selected)
    _ = input.off_data("data", selected)
    _ = input.once_data("data", data(trace, "once:"))
    input.append(Buffer.from_string("a"))
    assert_equal(require_buffer(retained_alias.read()).to_string(), "a")
    input.append(Buffer.from_string("b"))
    assert_equal(require_buffer(input.read()).to_string(), "b")
    assert_equal(trace.read(), "selected:aonce:aselected:b")
    _ = retained_alias.off_data("data", selected)
    input.append(Buffer.from_string("c"))
    _ = input.read()
    assert_equal(trace.read(), "selected:aonce:aselected:b")
    input.close()
    drain()


def ordered_pipes_share_bytes(root: String) raises:
    var input = Readable()
    var trace = Location(String())
    var first = create_write_stream(root + "/first")
    var second = create_write_stream(root + "/second")
    _ = input.on_data("data", data(trace, "first:", 88))
    _ = input.pipe_to(first)
    _ = input.on_data("data", data(trace, "second:", 89))
    _ = input.pipe_to(second)
    var bytes = Buffer.from_string("abc")
    input.append(bytes)
    input._accept_read(None)
    drain()
    assert_equal(trace.read(), "first:abcsecond:Xbc")
    assert_equal(read_text_file(root + "/first"), "Xbc")
    assert_equal(read_text_file(root + "/second"), "Ybc")
    assert_equal(bytes.to_string(), "Ybc")
    assert_equal(len(input._state[].pipes), 0)
    assert_true(input._state[].events.state[].data.has_listeners())
    var late = create_write_stream(root + "/late")
    _ = input.pipe_to(late)
    assert_false(late.writable_ended())
    drain()
    assert_true(late.writable_ended())


def paused_and_decoded(root: String) raises:
    write_text_file(root + "/unicode", "😀é")
    var input = create_read_stream(root + "/unicode")
    _ = input.set_encoding("utf8")
    var trace = Location(String())
    _ = input.once_empty("end", notification(trace, ":end"))
    _ = input.once_empty("close", notification(trace, ":close"))
    _ = input.pause()
    _ = input.on_data("data", data(trace))
    _ = poll_readables()
    assert_equal(trace.read(), "")
    assert_equal(input.bytes_read(), 0)
    _ = input.resume()
    drain()
    assert_equal(trace.read(), "😀é:end:close")
    assert_true(input.readable_ended())
    input.close()
    drain()
    assert_equal(trace.read(), "😀é:end:close")


def callback_failure_does_not_destroy_source() raises:
    var input = Readable()
    var trace = Location(String())
    var failing = data(trace, "", -1, True)
    _ = input.on_data("data", failing)
    input.append(Buffer.from_string("first"))
    var rejected = False
    try:
        _ = poll_readables()
    except error:
        rejected = "selected data callback failure" in String(error)
    assert_true(rejected)
    assert_true(input.readable())
    _ = input.off_data("data", failing)
    _ = input.on_data("data", data(trace))
    input.append(Buffer.from_string("next"))
    input._accept_read(None)
    drain()
    assert_equal(trace.read(), "firstnext")


def input_error_is_not_eof() raises:
    var input = Readable(-1)
    var trace = Location(String())
    var environment = allocate_callable_environment(
        Action(trace, "error", -1, False), destroy_callable_environment[Action]
    )
    _ = input.on_error("error", ReadErrorCallback(environment, Action.error))
    _ = input.on_empty("end", notification(trace, "unexpected-end"))
    _ = input.on_empty("close", notification(trace, ":close"))
    _ = input.on_data("data", data(trace, "unexpected-data"))
    drain()
    assert_equal(trace.read(), "error:close")
    assert_false(input.readable_ended())


def readline_and_pipe_share_input(root: String) raises:
    var input = Readable()
    var trace = Location(String())
    _ = input.on_data("data", data(trace, "data:"))
    var output = create_write_stream(root + "/lines")
    _ = input.pipe_to(output)
    var options = ReadLineOptions()
    options.input = input
    var interface = create_interface(options)
    var environment = allocate_callable_environment(
        Action(trace, ":answer:", -1, False),
        destroy_callable_environment[Action],
    )
    interface.question("", QuestionCallback(environment, Action.answer))
    input.append(Buffer.from_string("shared\n"))
    input._accept_read(None)
    drain()
    assert_equal(trace.read(), "data:shared\n:answer:shared")
    assert_equal(read_text_file(root + "/lines"), "shared\n")
    assert_true(output.writable_ended())
    var weak = WeakPointer(downgrade=interface._state)
    interface = create_interface(ReadLineOptions())
    assert_false(Bool(weak.try_upgrade()))
    interface.close()
    drain()


def register_temporary_source(path: String, trace: Location[String]) raises:
    var source = create_read_stream(path)
    _ = source.on_data("data", data(trace))


def temporary_source_is_retained(root: String) raises:
    write_text_file(root + "/temporary", "retained")
    var trace = Location(String())
    register_temporary_source(root + "/temporary", trace)
    drain()
    assert_equal(trace.read(), "retained")


def main() raises:
    manual_and_listener_identity()
    callback_failure_does_not_destroy_source()
    input_error_is_not_eof()
    var root = mkdtemp(prefix="mojo-readable-events-")
    try:
        ordered_pipes_share_bytes(root)
        paused_and_decoded(root)
        readline_and_pipe_share_input(root)
        temporary_source_is_retained(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
