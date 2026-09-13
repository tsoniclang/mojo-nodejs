from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsSymbol, JsValue
from tsonic_node.events import (
    EventEmitter,
    Listener0,
    Listener1,
    Listener2,
    Listener3,
)
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    allocate_callable_environment,
    destroy_callable_environment,
)


@fieldwise_init
struct Record:
    var trace: Location[String]
    var name: String

    @staticmethod
    def zero(context: ErasedCallableContext, var arguments: Tuple[]) raises:
        var record = context.unsafe_bitcast[Record]()
        record[].trace.write(record[].trace.read() + record[].name)

    @staticmethod
    def one(
        context: ErasedCallableContext, var arguments: Tuple[JsValue]
    ) raises:
        var record = context.unsafe_bitcast[Record]()
        record[].trace.write(record[].trace.read() + record[].name)
        assert_true(arguments[0].is_number())
        assert_equal(arguments[0].number_value(), 42.0)

    @staticmethod
    def two(
        context: ErasedCallableContext, var arguments: Tuple[JsValue, JsValue]
    ) raises:
        var record = context.unsafe_bitcast[Record]()
        record[].trace.write(record[].trace.read() + record[].name)
        assert_equal(arguments[0].number_value(), 42.0)
        assert_true(arguments[1].is_undefined())

    @staticmethod
    def three(
        context: ErasedCallableContext,
        var arguments: Tuple[JsValue, JsValue, JsValue],
    ) raises:
        var record = context.unsafe_bitcast[Record]()
        record[].trace.write(record[].trace.read() + record[].name)
        assert_true(arguments[0].is_undefined())
        assert_true(arguments[1].is_undefined())
        assert_true(arguments[2].is_undefined())

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Record](context)


def record(trace: Location[String], name: String) -> Listener0:
    return Listener0(
        allocate_callable_environment(Record(trace, name), Record.destroy),
        Record.zero,
    )


@fieldwise_init
struct DuringEmit:
    var trace: Location[String]
    var emitter: EventEmitter
    var remove: Listener0
    var reenter: Bool
    var fail: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[DuringEmit]()
        action[].trace.write(action[].trace.read() + "A")
        var event = JsValue(JsString("event"))
        _ = action[].emitter.off_callable(event, action[].remove)
        _ = action[].emitter.on_callable(event, record(action[].trace, "D"))
        if action[].reenter:
            _ = action[].emitter.emit_callable(event)
        if action[].fail:
            raise Error("deliberate callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[DuringEmit](context)


def during(
    trace: Location[String],
    emitter: EventEmitter,
    remove: Listener0,
    reenter: Bool,
    fail: Bool,
) -> Listener0:
    return Listener0(
        allocate_callable_environment(
            DuringEmit(trace, emitter, remove, reenter, fail),
            DuringEmit.destroy,
        ),
        DuringEmit.invoke,
    )


def mixed_arity() raises:
    var emitter = EventEmitter()
    var trace = Location(String())
    var event = JsValue(JsString("event"))
    _ = emitter.on_callable1(
        event,
        Listener1(
            allocate_callable_environment(Record(trace, "B"), Record.destroy),
            Record.one,
        ),
    )
    _ = emitter.on_callable(event, record(trace, "C"))
    _ = emitter.prepend_callable2(
        event,
        Listener2(
            allocate_callable_environment(Record(trace, "A"), Record.destroy),
            Record.two,
        ),
    )
    assert_true(emitter.emit_callable1(event, JsValue(42.0)))
    assert_equal(trace.read(), "ABC")
    _ = emitter.remove_all_listeners()
    _ = emitter.once_callable3(
        event,
        Listener3(
            allocate_callable_environment(Record(trace, "D"), Record.destroy),
            Record.three,
        ),
    )
    assert_true(emitter.emit_callable(event))
    assert_false(emitter.emit_callable(event))
    assert_equal(trace.read(), "ABCD")


def duplicate_removal() raises:
    var emitter = EventEmitter()
    var trace = Location(String())
    var event = JsValue(JsString("event"))
    var first = record(trace, "A")
    _ = emitter.on_callable(event, first)
    _ = emitter.on_callable(event, record(trace, "B"))
    _ = emitter.on_callable(event, first)
    _ = emitter.off_callable(event, first)
    assert_true(emitter.emit_callable(event))
    assert_equal(trace.read(), "AB")


def reentrant_once() raises:
    var emitter = EventEmitter()
    var trace = Location(String())
    var event = JsValue(JsString("event"))
    var second = record(trace, "B")
    _ = emitter.once_callable(
        event, during(trace, emitter, second, True, False)
    )
    _ = emitter.once_callable(event, second)
    _ = emitter.once_callable(event, record(trace, "C"))
    assert_true(emitter.emit_callable(event))
    assert_equal(trace.read(), "ACDB")
    assert_equal(emitter.listener_count(event), 1.0)
    _ = emitter.remove_all_listeners()


def failing_once() raises:
    var emitter = EventEmitter()
    var trace = Location(String())
    var event = JsValue(JsString("event"))
    var absent = record(trace, "X")
    _ = emitter.once_callable(
        event, during(trace, emitter, absent, False, True)
    )
    _ = emitter.once_callable(event, record(trace, "B"))
    var failed = False
    try:
        _ = emitter.emit_callable(event)
    except:
        failed = True
    assert_true(failed)
    assert_equal(trace.read(), "A")
    assert_equal(emitter.listener_count(event), 2.0)
    assert_true(emitter.emit_callable(event))
    assert_equal(trace.read(), "ABD")
    _ = emitter.remove_all_listeners()


def event_keys() raises:
    var emitter = EventEmitter()
    var trace = Location(String())
    var callback = record(trace, "S")
    var symbol = JsValue(JsSymbol(JsString("error")))
    assert_false(emitter.emit_callable(symbol))
    var rejected = False
    try:
        _ = emitter.emit_callable(JsValue(JsString("error")))
    except:
        rejected = True
    assert_true(rejected)
    _ = emitter.on_callable(symbol, callback)
    _ = emitter.on_callable(JsValue(JsString("name")), callback)
    _ = emitter.on_callable(JsValue(JsString("10")), callback)
    _ = emitter.prepend_callable(JsValue(JsString("2")), callback)
    _ = emitter.prepend_callable(JsValue(JsString("01")), callback)
    var names = emitter.event_names()
    assert_equal(len(names), 5)
    assert_equal(names[0].string_value(), JsString("2"))
    assert_equal(names[1].string_value(), JsString("10"))
    assert_equal(names[2].string_value(), JsString("name"))
    assert_equal(names[3].string_value(), JsString("01"))
    assert_true(names[4].same_identity(symbol))
    _ = emitter.set_max_listeners(1.5)
    assert_equal(emitter.get_max_listeners(), 1.5)
    _ = emitter.set_max_listeners(Float64(FloatLiteral.infinity))
    assert_equal(emitter.get_max_listeners(), Float64(FloatLiteral.infinity))


def main() raises:
    mixed_arity()
    duplicate_removal()
    reentrant_once()
    failing_once()
    event_keys()
