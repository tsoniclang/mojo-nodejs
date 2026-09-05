from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsValue, js_value_error
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.events import EventEmitter, listener_count
from tsonic_node.readline import ReadLineOptions, create_interface
from tsonic_node.stream import Readable, Writable
from tsonic_node.worker_threads import (
    get_environment_data,
    is_main_thread,
    is_marked_as_untransferable,
    mark_as_untransferable,
    message_channel_new,
    poll_worker_threads,
    receive_message_on_port,
    set_environment_data,
)
from tsonic_node.buffer import Buffer


@fieldwise_init
struct EmptyEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[]) raises:
        var environment = context.unsafe_bitcast[EmptyEnvironment]()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[EmptyEnvironment](context)


@fieldwise_init
struct ValueEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[JsValue]
    ) raises:
        var environment = context.unsafe_bitcast[ValueEnvironment]()
        assert_true(arguments[0].is_string())
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[ValueEnvironment](context)


@fieldwise_init
struct AnswerEnvironment:
    var value: Location[String]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[String]
    ) raises:
        var environment = context.unsafe_bitcast[AnswerEnvironment]()
        environment[].value.write(arguments[0])

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[AnswerEnvironment](context)


def empty_callback(count: Location[Int]) -> RaisingCallable[Tuple[], NoneType]:
    var environment = allocate_callable_environment(
        EmptyEnvironment(count), EmptyEnvironment.destroy
    )
    return RaisingCallable[Tuple[], NoneType](
        environment, EmptyEnvironment.invoke
    )


def value_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[JsValue], NoneType]:
    var environment = allocate_callable_environment(
        ValueEnvironment(count), ValueEnvironment.destroy
    )
    return RaisingCallable[Tuple[JsValue], NoneType](
        environment, ValueEnvironment.invoke
    )


def answer_callback(
    value: Location[String],
) -> RaisingCallable[Tuple[String], NoneType]:
    var environment = allocate_callable_environment(
        AnswerEnvironment(value), AnswerEnvironment.destroy
    )
    return RaisingCallable[Tuple[String], NoneType](
        environment, AnswerEnvironment.invoke
    )


def main() raises:
    var event_count = Location(0)
    var emitter = EventEmitter()
    _ = emitter.once_callable(
        JsValue(JsString("ready")), empty_callback(event_count)
    )
    assert_equal(listener_count(emitter, JsValue(JsString("ready"))), 1.0)
    assert_true(emitter.emit_callable(JsValue(JsString("ready"))))
    assert_false(emitter.emit_callable(JsValue(JsString("ready"))))
    assert_equal(event_count.read(), 1)

    var channel = message_channel_new()
    var message_count = Location(0)
    _ = channel.port2.on_callable1(
        JsValue(JsString("message")), value_callback(message_count)
    )
    channel.port1.post_message(JsValue(JsString("payload")))
    var received = receive_message_on_port(channel.port2)
    assert_true(received.is_string())
    assert_equal(received.string_value(), JsString("payload"))
    assert_false(received.same_identity(JsValue(JsString("payload"))))
    _ = channel.port2.unref_chain()
    assert_false(channel.port2.has_ref())
    _ = channel.port2.ref_chain()
    assert_true(channel.port2.has_ref())
    channel.port1.post_message(JsValue(JsString("event")))
    assert_true(poll_worker_threads())
    assert_equal(message_count.read(), 1)

    set_environment_data("mode", JsValue(JsString("test")))
    assert_equal(get_environment_data("mode").string_value(), JsString("test"))
    assert_true(is_main_thread())

    var identity = js_value_error("identity")
    mark_as_untransferable(identity)
    assert_true(is_marked_as_untransferable(identity))
    assert_false(is_marked_as_untransferable(js_value_error("identity")))

    var input = Readable()
    input.append(Buffer.from_string("answer\n"))
    var options = ReadLineOptions()
    options.input = input
    options.output = Optional(Writable())
    var lines = create_interface(options)
    var answer = Location(String())
    lines.question("name? ", answer_callback(answer))
    assert_equal(answer.read(), "answer")
