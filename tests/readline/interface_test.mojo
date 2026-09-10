from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from std.time import monotonic, sleep
from tsonic_runtime import Location, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_node.buffer import Buffer
from tsonic_node.filesystem import RmOptions, read_text_file, remove_path, write_text_file
from tsonic_node.filesystem.streams import ReadStreamOptions, create_read_stream, create_write_stream
from tsonic_node.readline import Interface, QuestionCallback, ReadLineOptions, create_interface, has_pending_readline
from support.input_events import poll_input_events
from tsonic_node.stream import Readable


@fieldwise_init
struct AnswerAction:
    var trace: Location[String]
    var interface: Optional[Interface]
    var remaining: Int
    var fail: Bool
    var reenter: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[String]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + "[" + arguments[0] + "]")
        if action[].remaining > 1:
            action[].interface.value().question("next? ", answer(action[].trace, action[].interface, action[].remaining - 1))
        if action[].reenter:
            _ = poll_input_events()
        if action[].fail:
            raise Error("deliberate answer failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def answer(trace: Location[String], interface: Optional[Interface] = None, remaining: Int = 1, fail: Bool = False, reenter: Bool = False) -> QuestionCallback:
    var context = allocate_callable_environment(AnswerAction(trace, interface, remaining, fail, reenter), AnswerAction.destroy)
    return QuestionCallback(context, AnswerAction.invoke)


def drain_questions() raises:
    var deadline = monotonic() + 10000000000
    while has_pending_readline():
        assert_true(monotonic() < deadline)
        _ = poll_input_events()
        sleep(0.001)


def retained_input() raises:
    var options = ReadLineOptions()
    var input = options.input
    var interface = create_interface(options)
    var alias = interface
    var trace = Location(String())
    interface.question("first? ", answer(trace, interface, 3))
    assert_equal(trace.read(), "")
    _ = poll_input_events()
    assert_true(has_pending_readline())
    _ = alias.pause()
    assert_true(input.is_paused())
    input.append(Buffer.from_string("first\n\nlast\n"))
    assert_false(poll_input_events())
    assert_equal(trace.read(), "")
    _ = alias.resume()
    assert_false(input.is_paused())
    assert_true(poll_input_events())
    assert_equal(trace.read(), "[first][][last]")
    assert_true(has_pending_readline())
    alias.close()
    assert_false(has_pending_readline())
    assert_true(input.readable())


def chunk_splits() raises:
    var bytes = Buffer.from_string("a😀é\n")
    for split in range(len(bytes) + 1):
        var options = ReadLineOptions()
        var input = options.input
        var interface = create_interface(options)
        var trace = Location(String())
        interface.question("", answer(trace))
        input.append(bytes.subarray(0, Float64(split)))
        _ = poll_input_events()
        if split != len(bytes):
            assert_equal(trace.read(), "")
        input.append(bytes.subarray(Float64(split)))
        _ = poll_input_events()
        assert_equal(trace.read(), "[a😀é]")
        interface.close()


def simulated_input(root: String) raises:
    var output = create_write_stream(root + "/prompts")
    var options = ReadLineOptions()
    options.output = output
    var interface = create_interface(options)
    var trace = Location(String())
    var ignored = Location(String())
    interface.question("name? ", answer(trace))
    interface.question("ignored? ", answer(ignored))
    assert_equal(read_text_file(root + "/prompts"), "name? name? ")
    interface.write("😀")
    assert_equal(interface.line(), "😀")
    assert_equal(interface.cursor(), 2.0)
    _ = interface.pause()
    assert_true(interface.is_paused())
    interface.write("\n")
    assert_false(interface.is_paused())
    assert_equal(trace.read(), "[😀]")
    assert_equal(ignored.read(), "")
    assert_equal(interface.line(), "")
    interface.set_prompt("custom> ")
    assert_equal(interface.get_prompt(), "custom> ")
    interface.prompt()
    assert_equal(read_text_file(root + "/prompts"), "name? name? custom> ")
    interface.question("closed? ", answer(trace))
    interface.close()
    assert_false(has_pending_readline())
    assert_true(output.writable())
    _ = output.end()
    var rejected = False
    try:
        interface.question("", answer(trace))
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(trace.read(), "[😀]")


def retained_history() raises:
    var options = ReadLineOptions()
    options.terminal = True
    options.historySize = 2.0
    options.removeHistoryDuplicates = True
    var interface = create_interface(options)
    interface.write("😀\nnext\n😀\nthird\n")
    assert_equal(len(interface._state[].history), 2)
    assert_equal(interface._state[].history[0], "third")
    assert_equal(interface._state[].history[1], "😀")
    interface.close()
    for invalid in (-1.0, 1.5, 1048577.0):
        options.historySize = invalid
        var rejected = False
        try:
            _ = create_interface(options)
        except:
            rejected = True
        assert_true(rejected)


def eof_and_ranges(root: String) raises:
    write_text_file(root + "/lines", "xxfirst\r\n😀\nlastyy")
    var read_options = ReadStreamOptions()
    read_options.high_water_mark = 1
    read_options.start = 2
    read_options.end = 17
    var options = ReadLineOptions()
    options.input = create_read_stream(root + "/lines", read_options)
    var interface = create_interface(options)
    var trace = Location(String())
    interface.question("", answer(trace, interface, 3))
    drain_questions()
    assert_equal(trace.read(), "[first][😀][last]")
    assert_true(interface._state[].closed)
    assert_equal(options.input.bytes_read(), 16.0)
    write_text_file(root + "/empty", "")
    options.input = create_read_stream(root + "/empty")
    interface = create_interface(options)
    trace = Location(String())
    interface.question("", answer(trace))
    drain_questions()
    assert_equal(trace.read(), "")
    assert_true(interface._state[].closed)


def callback_failure_retains_other_work() raises:
    var first_options = ReadLineOptions()
    first_options.input.append(Buffer.from_string("first\nnext\n"))
    first_options.input._accept_read(None)
    var first = create_interface(first_options)
    var second_options = ReadLineOptions()
    second_options.input.append(Buffer.from_string("other\n"))
    second_options.input._accept_read(None)
    var second = create_interface(second_options)
    var trace = Location(String())
    first.question("", answer(trace, first, 2, True))
    second.question("", answer(trace))
    var rejected = False
    try:
        _ = poll_input_events()
    except error:
        rejected = "deliberate answer failure" in String(error)
    assert_true(rejected)
    assert_equal(trace.read(), "[first]")
    drain_questions()
    assert_equal(trace.read(), "[first][next][other]")
    first.close()
    second.close()


def eof_reentry() raises:
    var options = ReadLineOptions()
    options.input.append(Buffer.from_string("first\nsecond"))
    options.input._accept_read(None)
    var interface = create_interface(options)
    var trace = Location(String())
    interface.question("", answer(trace, interface, 2, False, True))
    drain_questions()
    assert_equal(trace.read(), "[first][second]")
    assert_true(interface._state[].closed)


def interface_consumes_between_questions() raises:
    var options = ReadLineOptions()
    var input = options.input
    var interface = create_interface(options)
    assert_true(has_pending_readline())
    input.append(Buffer.from_string("old\ncurrent"))
    assert_true(poll_input_events())
    assert_equal(interface.line(), "current")
    var trace = Location(String())
    interface.question("", answer(trace))
    assert_false(poll_input_events())
    assert_equal(trace.read(), "")
    input.append(Buffer.from_string("\n"))
    assert_true(poll_input_events())
    assert_equal(trace.read(), "[current]")
    assert_true(has_pending_readline())
    input._accept_read(None)
    drain_questions()
    assert_true(interface._state[].closed)


def eof_callback_failure() raises:
    var options = ReadLineOptions()
    options.input.append(Buffer.from_string("tail"))
    options.input._accept_read(None)
    var interface = create_interface(options)
    var trace = Location(String())
    interface.question("", answer(trace, interface, 2, True))
    var rejected = False
    var deadline = monotonic() + 10000000000
    while not rejected:
        assert_true(monotonic() < deadline)
        try:
            _ = poll_input_events()
        except error:
            rejected = "deliberate answer failure" in String(error)
    assert_equal(trace.read(), "[tail]")
    drain_questions()
    assert_equal(trace.read(), "[tail]")
    assert_true(interface._state[].closed)


def main() raises:
    retained_input()
    chunk_splits()
    retained_history()
    callback_failure_retains_other_work()
    eof_reentry()
    eof_callback_failure()
    interface_consumes_between_questions()
    var root = mkdtemp(prefix="mojo-readline-")
    try:
        simulated_input(root)
        eof_and_ranges(root)
    finally:
        remove_path(root, RmOptions(recursive=True))
