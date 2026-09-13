from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_runtime import (
    Location,
    RaisingCallable,
    TsError,
    error_new,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node import Buffer, RmOptions, read_text_file, remove_path
from tsonic_node.filesystem.descriptors import open_file
from tsonic_node.filesystem.streams import create_write_stream
from tsonic_node.stream.descriptor import StreamDescriptor
from tsonic_node.stream.writable import Writable
from tsonic_node.stream.completion import WriteCallback
from tsonic_node.internal.callback_queue import Notification
from tsonic_node.event_loop import run_event_loop


@fieldwise_init
struct Trace:
    var value: Location[String]
    var label: String
    var failed: Bool

    @staticmethod
    def complete(
        context: ErasedCallableContext, var arguments: Tuple[Optional[TsError]]
    ) raises:
        var trace = context.unsafe_bitcast[Self]()
        assert_equal(Bool(arguments[0]), trace[].failed)
        trace[].value.write(trace[].value.read() + trace[].label)

    @staticmethod
    def event(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var trace = context.unsafe_bitcast[Self]()
        trace[].value.write(trace[].value.read() + trace[].label)

    @staticmethod
    def error(
        context: ErasedCallableContext, var arguments: Tuple[TsError]
    ) raises:
        assert_equal(arguments[0].message, "cancelled")
        Self.event(context, ())


def callback(
    trace: Location[String], label: String, failed: Bool
) -> WriteCallback:
    var environment = allocate_callable_environment(
        Trace(trace, label, failed), destroy_callable_environment[Trace]
    )
    return WriteCallback(environment, Trace.complete)


def notification(trace: Location[String], label: String) -> Notification:
    var environment = allocate_callable_environment(
        Trace(trace, label, False), destroy_callable_environment[Trace]
    )
    return Notification(environment, Trace.event)


def cancelled_pending_output(root: String, with_error: Bool) raises:
    var trace = Location(String())
    var output = create_write_stream(root + "/cancelled")
    var retained_output = output
    _ = output.on_empty("finish", notification(trace, "bad-finish"))
    _ = output.on_empty("drain", notification(trace, "bad-drain"))
    _ = output.on_empty("close", notification(trace, "c"))
    var error_environment = allocate_callable_environment(
        Trace(trace, "e", False), destroy_callable_environment[Trace]
    )
    _ = output.on_error(
        "error",
        RaisingCallable[Tuple[TsError], NoneType](
            error_environment, Trace.error
        ),
    )
    output.cork()
    _ = output.write_string_callback(
        "never written", callback(trace, "w", True)
    )
    _ = retained_output.destroy(
        error_new("cancelled") if with_error else Optional[TsError]()
    )
    _ = output.destroy(error_new("ignored second error"))
    _ = output.end_callback(callback(trace, "z", True))
    assert_true(retained_output.destroyed())
    assert_true(retained_output.closed())
    assert_true(retained_output.writable_aborted())
    assert_false(retained_output.writable())
    assert_false(retained_output.writable_ended())
    assert_false(retained_output.writable_finished())
    assert_equal(Bool(retained_output.errored()), with_error)
    assert_equal(retained_output.writable_length(), 0.0)
    assert_false(retained_output.writable_need_drain())
    assert_equal(read_text_file(root + "/cancelled"), "")
    assert_equal(trace.read(), "")
    run_event_loop()
    assert_equal(trace.read(), "wecz" if with_error else "wcz")


def cancel_queued_finish(root: String) raises:
    var trace = Location(String())
    var descriptor = StreamDescriptor(
        Int32(open_file(root + "/pending", "w")), True
    )
    var output = Writable(descriptor, root + "/pending", None, False, False, 3)
    _ = output.on_empty("finish", notification(trace, "bad-finish"))
    _ = output.on_empty("close", notification(trace, "c"))
    _ = output.end_string_callback("stored", callback(trace, "z", True))
    _ = output.destroy()
    run_event_loop()
    assert_equal(trace.read(), "zc")
    assert_equal(read_text_file(root + "/pending"), "stored")
    assert_true(output.writable_ended())
    assert_false(output.writable_finished())


def borrowed_descriptor_survives(root: String) raises:
    var descriptor = StreamDescriptor(
        Int32(open_file(root + "/borrowed", "w")), True
    )
    var output = Writable(descriptor._state[].descriptor, False)
    _ = output.set_default_encoding("utf16le")
    var rejected = False
    try:
        _ = output.set_default_encoding("not-an-encoding")
    except:
        rejected = True
    assert_true(rejected)
    _ = output.write_string("A")
    _ = output.destroy()
    assert_true(descriptor.is_open())
    _ = descriptor.write(Buffer.from_string("tail"), None)
    descriptor.close()
    run_event_loop()
    from tsonic_node import read_file

    var bytes = read_file(root + "/borrowed").copy_bytes()
    assert_equal(len(bytes), 6)
    assert_equal(bytes[0], Byte(65))
    assert_equal(bytes[1], Byte(0))


def main() raises:
    var root = mkdtemp(prefix="tsonic-stream-destroy-")
    try:
        cancelled_pending_output(root, False)
        cancelled_pending_output(root, True)
        cancel_queued_finish(root)
        borrowed_descriptor_survives(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
