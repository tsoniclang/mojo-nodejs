from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_runtime import (
    Location,
    RaisingCallable,
    TsError,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node import (
    Buffer,
    RmOptions,
    read_text_file,
    remove_path,
    write_text_file,
)
from tsonic_node.filesystem.streams import (
    WriteStreamOptions,
    create_write_stream,
)
from tsonic_node.internal.callback_queue import Notification
from tsonic_node.stream.completion import (
    WriteCallback,
    has_pending_streams,
    poll_streams,
)
from tsonic_node.stream.writable import StreamChunk
from tsonic_node.event_loop import run_event_loop


@fieldwise_init
struct Action:
    var trace: Location[String]
    var path: String
    var name: String
    var fail: Bool
    var failed_write: Bool
    var contents: String

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[Optional[TsError]]
    ) raises:
        var action = context.unsafe_bitcast[Self]()
        assert_equal(read_text_file(action[].path), action[].contents)
        assert_equal(Bool(arguments[0]), action[].failed_write)
        if arguments[0]:
            assert_true(len(arguments[0].value().message) != 0)
        action[].trace.write(action[].trace.read() + action[].name)
        if action[].fail:
            raise Error("deliberate callback error")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def completion(
    trace: Location[String],
    path: String,
    name: String,
    fail: Bool = False,
    failed_write: Bool = False,
    contents: String = "éABC",
) -> WriteCallback:
    var context = allocate_callable_environment(
        Action(trace, path, name, fail, failed_write, contents), Action.destroy
    )
    return WriteCallback(context, Action.invoke)


@fieldwise_init
struct Event:
    var trace: Location[String]
    var name: String

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var event = context.unsafe_bitcast[Self]()
        event[].trace.write(event[].trace.read() + event[].name)

    @staticmethod
    def error(
        context: ErasedCallableContext, var arguments: Tuple[TsError]
    ) raises:
        assert_true(len(arguments[0].message) != 0)
        Self.invoke(context, ())


def notification(trace: Location[String], name: String) -> Notification:
    var context = allocate_callable_environment(
        Event(trace, name), destroy_callable_environment[Event]
    )
    return Notification(context, Event.invoke)


def error_listener(
    trace: Location[String], name: String
) -> RaisingCallable[Tuple[TsError], NoneType]:
    var context = allocate_callable_environment(
        Event(trace, name), destroy_callable_environment[Event]
    )
    return RaisingCallable[Tuple[TsError], NoneType](context, Event.error)


def encoded_completion(root: String) raises:
    var path = root + "/encoded"
    var trace = Location(String())
    var output = create_write_stream(path)
    var retained_alias = output
    output.cork()
    retained_alias.cork()
    _ = output.on_empty("finish", notification(trace, "f"))
    _ = output.once_empty("close", notification(trace, "x"))
    _ = output.write_string_encoded(
        "c3a9", String("hex"), completion(trace, path, "a", True)
    )
    _ = retained_alias.write_buffer_encoded(
        Buffer.from_string("A"),
        String("not-an-encoding"),
        completion(trace, path, "b"),
    )
    assert_false(has_pending_streams())
    assert_false(poll_streams())
    assert_equal(trace.read(), "")
    retained_alias.uncork()
    assert_equal(read_text_file(path), "")
    _ = output.write_value_encoded(
        StreamChunk(String("Qg==")),
        String("base64"),
        completion(trace, path, "c"),
    )
    _ = retained_alias.end_value_encoded(
        StreamChunk(Buffer.from_string("C")),
        String("ignored"),
        completion(trace, path, "z"),
    )
    _ = output.end_callback(completion(trace, path, "q"))
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
    assert_equal(trace.read(), "abczqfx")
    assert_false(has_pending_streams())
    _ = output.end_empty_encoded(
        None, None, completion(trace, path, "r", False, True)
    )
    assert_equal(trace.read(), "abczqfx")
    run_event_loop()
    assert_equal(trace.read(), "abczqfxr")
    _ = output.on_error(
        "error", error_listener(trace, "must-not-error-after-close")
    )
    assert_false(
        output.write_string_callback(
            "late", completion(trace, path, "l", False, True)
        )
    )
    run_event_loop()
    assert_equal(trace.read(), "abczqfxrl")
    assert_equal(len(output._state[].events.state[].reservations), 0)


def failed_writes_complete_before_error(root: String) raises:
    var path = root + "/failures"
    var trace = Location(String())
    var output = create_write_stream(path)
    var rejected = False
    try:
        _ = output.write_string_encoded(
            "bad", String("unknown"), completion(trace, path, "bad")
        )
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(read_text_file(path), "")
    assert_true(output.writable())
    assert_false(has_pending_streams())
    _ = output.end()
    run_event_loop()
    write_text_file(path, "unchanged")
    var options = WriteStreamOptions()
    options.flags = String("r")
    output = create_write_stream(path, options)
    _ = output.on_error("error", error_listener(trace, "e"))
    _ = output.once_empty("close", notification(trace, "c"))
    _ = output.on_empty("finish", notification(trace, "must-not-finish"))
    output.cork()
    _ = output.write_string_callback(
        "a", completion(trace, path, "a", True, True, "unchanged")
    )
    _ = output.write_string_callback(
        "b", completion(trace, path, "b", False, True, "unchanged")
    )
    _ = output.end_callback(
        completion(trace, path, "z", False, True, "unchanged")
    )
    assert_true(has_pending_streams())
    assert_equal(trace.read(), "")
    rejected = False
    try:
        _ = poll_streams()
    except:
        rejected = True
    assert_true(rejected)
    assert_true(has_pending_streams())
    assert_equal(trace.read(), "a")
    assert_equal(read_text_file(path), "unchanged")
    run_event_loop()
    assert_equal(trace.read(), "abzec")
    _ = output.end_callback(
        completion(trace, path, "r", False, True, "unchanged")
    )
    run_event_loop()
    assert_false(has_pending_streams())
    assert_equal(trace.read(), "abzecr")


def successful_prefix_survives_failure(root: String) raises:
    var path = root + "/prefix"
    var trace = Location(String())
    var output = create_write_stream(path)
    _ = output.on_error("error", error_listener(trace, "event"))
    _ = output.write_string_callback(
        "éABC", completion(trace, path, "completed")
    )
    output._state[].descriptor.value().close()
    assert_false(
        output.write_string_callback(
            "late", completion(trace, path, "failed", False, True)
        )
    )
    assert_true(has_pending_streams())
    assert_equal(trace.read(), "")
    run_event_loop()
    assert_equal(trace.read(), "completedfailedevent")
    assert_false(has_pending_streams())


def pressure_notification_order(root: String) raises:
    var path = root + "/drain"
    var trace = Location(String())
    var options = WriteStreamOptions()
    options.high_water_mark = Float64(1)
    var output = create_write_stream(path, options)
    var listener = notification(trace, "d")
    _ = output.once_empty("drain", listener)
    _ = output.on_empty("finish", notification(trace, "f"))
    _ = output.on_empty("close", notification(trace, "c"))
    output.cork()
    assert_false(
        output.write_string_callback("éABC", completion(trace, path, "w"))
    )
    output.uncork()
    assert_equal(trace.read(), "")
    run_event_loop()
    assert_equal(trace.read(), "wd")
    _ = output.off_empty("drain", listener)
    _ = output.end_callback(completion(trace, path, "z"))
    run_event_loop()
    assert_equal(trace.read(), "wdzfc")


def main() raises:
    var root = mkdtemp(prefix="tsonic-stream-completion-")
    try:
        encoded_completion(root)
        failed_writes_complete_before_error(root)
        successful_prefix_survives_failure(root)
        pressure_notification_order(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
