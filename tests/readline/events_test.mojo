from std.testing import assert_equal, assert_false, assert_true
from tsonic_runtime import Location, TsError, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_node.buffer import Buffer
from tsonic_node.internal.callback_queue import Notification
from tsonic_node.readline import Interface, ReadLineOptions, create_interface, has_pending_readline
from tsonic_node.readline.events import LineCallback, ErrorCallback
from support.input_events import poll_input_events


@fieldwise_init
struct Action:
    var trace: Location[String]
    var label: String
    var fail: Bool
    var interface: Optional[Interface]
    var operation: String

    def complete(self) raises:
        if self.interface:
            if self.operation == "write":
                self.interface.value().write("nested\n")
            elif self.operation == "pause":
                _ = self.interface.value().pause()
            elif self.operation == "close":
                self.interface.value().close()
        if self.fail:
            raise Error("selected readline failure")

    @staticmethod
    def line(context: ErasedCallableContext, var arguments: Tuple[String]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + action[].label + "[" + arguments[0] + "]")
        action[].complete()

    @staticmethod
    def empty(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + action[].label)
        action[].complete()

    @staticmethod
    def error(context: ErasedCallableContext, var arguments: Tuple[TsError]) raises:
        var action = context.unsafe_bitcast[Self]()
        var error = arguments[0].copy()
        assert_equal(error.name, "SelectedError")
        assert_equal(error.message, "exact input error")
        assert_equal(error.stack.value(), "exact stack")
        action[].trace.write(action[].trace.read() + action[].label)


def line(trace: Location[String], label: String = "", fail: Bool = False, interface: Optional[Interface] = None, operation: String = "") -> LineCallback:
    var environment = allocate_callable_environment(Action(trace, label, fail, interface, operation), destroy_callable_environment[Action])
    return LineCallback(environment, Action.line)


def empty(trace: Location[String], label: String, fail: Bool = False, interface: Optional[Interface] = None, operation: String = "") -> Notification:
    var environment = allocate_callable_environment(Action(trace, label, fail, interface, operation), destroy_callable_environment[Action])
    return Notification(environment, Action.empty)


def line_question_and_eof() raises:
    var options = ReadLineOptions()
    var interface = create_interface(options)
    var trace = Location(String())
    var selected = line(trace, "line")
    var alias = interface.on_line("line", selected)
    _ = alias.on_line("line", selected)
    _ = interface.off_line("line", selected)
    _ = alias.once_line("line", line(trace, "once"))
    _ = interface.on_empty("close", empty(trace, "close"))
    interface.question("", line(trace, "answer"))
    interface.write("first\n\n😀\n")
    assert_equal(trace.read(), "answer[first]line[]once[]line[😀]")
    alias.question("", line(trace, "wrong-tail-answer"))
    options.input.append(Buffer.from_string("tail"))
    options.input._accept_read(None)
    for attempt in range(100):
        if not has_pending_readline():
            break
        _ = poll_input_events()
    assert_false(has_pending_readline())
    assert_equal(trace.read(), "answer[first]line[]once[]line[😀]line[tail]close")


def transitions_and_reentry() raises:
    var interface = create_interface(ReadLineOptions())
    var trace = Location(String())
    _ = interface.on_empty("pause", empty(trace, "P"))
    _ = interface.on_empty("resume", empty(trace, "R"))
    _ = interface.once_empty("close", empty(trace, "C", interface=interface, operation="close"))
    _ = interface.pause()
    _ = interface.pause()
    _ = interface.resume()
    _ = interface.resume()
    _ = interface.once_line("line", line(trace, "once", interface=interface, operation="write"))
    _ = interface.on_line("line", line(trace, "all"))
    interface.write("outer\n")
    assert_equal(trace.read(), "PRonce[outer]all[outer]all[nested]")
    interface.close()
    interface.close()
    assert_equal(trace.read(), "PRonce[outer]all[outer]all[nested]PC")
    assert_false(has_pending_readline())


def callback_failure_retains_lines() raises:
    var interface = create_interface(ReadLineOptions())
    var trace = Location(String())
    _ = interface.once_line("line", line(trace, "fail", True))
    _ = interface.on_line("line", line(trace, "line"))
    var rejected = False
    try:
        interface.write("first\nsecond\n")
    except error:
        rejected = String(error) == "selected readline failure"
    assert_true(rejected)
    assert_equal(trace.read(), "fail[first]")
    assert_true(poll_input_events())
    assert_equal(trace.read(), "fail[first]line[second]")
    interface.close()


def close_exception_boundaries() raises:
    var options = ReadLineOptions()
    var interface = create_interface(options)
    var trace = Location(String())
    _ = interface.once_empty("pause", empty(trace, "P", True))
    _ = interface.once_empty("close", empty(trace, "C", True))
    var rejected = False
    try:
        interface.close()
    except error:
        rejected = String(error) == "selected readline failure"
    assert_true(rejected)
    assert_false(interface._state[].closed)
    assert_true(has_pending_readline())
    rejected = False
    try:
        interface.close()
    except error:
        rejected = String(error) == "selected readline failure"
    assert_true(rejected)
    assert_true(interface._state[].closed)
    assert_false(has_pending_readline())
    assert_false(options.input._state[].events.state[].data.has_listeners())
    assert_false(options.input._state[].events.state[].errors.has_listeners())
    interface.close()
    assert_equal(trace.read(), "PC")


def input_error_identity() raises:
    var options = ReadLineOptions()
    var interface = create_interface(options)
    var trace = Location(String())
    var environment = allocate_callable_environment(Action(trace, "E", False, None, ""), destroy_callable_environment[Action])
    var callback = ErrorCallback(environment, Action.error)
    _ = interface.once_error("error", callback)
    var error = TsError("SelectedError", "exact input error", String("exact stack"))
    assert_true(options.input._state[].events.state[].errors.emit((error.copy(),)))
    assert_equal(trace.read(), "E")
    _ = interface.on_error("error", callback)
    _ = interface.off_error("error", callback)
    var rejected = False
    try:
        _ = options.input._state[].events.state[].errors.emit((error.copy(),))
    except caught:
        rejected = "exact input error" in String(caught)
    assert_true(rejected)
    assert_equal(trace.read(), "E")
    interface.close()


def main() raises:
    line_question_and_eof()
    transitions_and_reentry()
    callback_failure_retains_lines()
    close_exception_boundaries()
    input_error_identity()
