from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsValue
from tsonic_js.value import _JsValueBuilder
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.worker_threads import (
    MessageChannel,
    message_channel_new,
    receive_message_on_port,
    poll_worker_threads,
    mark_as_untransferable,
    is_marked_as_untransferable,
)


@fieldwise_init
struct Completion:
    var count: Location[Int]
    var created: Location[Optional[MessageChannel]]
    var fail: Bool

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[JsValue]
    ) raises:
        var environment = context.unsafe_bitcast[Completion]()
        environment[].count.write(environment[].count.read() + 1)
        if not environment[].created.read():
            var channel = message_channel_new()
            environment[].created.write(channel)
            _ = channel.port2.on_callable1(
                JsValue(JsString("message")),
                callback(environment[].count, environment[].created),
            )
            channel.port1.post_message(arguments[0])
        if environment[].fail:
            raise Error("deliberate message callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Completion](context)


def callback(
    count: Location[Int],
    created: Location[Optional[MessageChannel]],
    fail: Bool = False,
) -> RaisingCallable[Tuple[JsValue], NoneType]:
    var environment = allocate_callable_environment(
        Completion(count, created, fail), Completion.destroy
    )
    return RaisingCallable[Tuple[JsValue], NoneType](
        environment, Completion.invoke
    )


def main() raises:
    var channel = message_channel_new()
    channel.port1.post_message(JsValue.undefined())
    var received = receive_message_on_port(channel.port2)
    assert_true(Bool(received))
    assert_true(received.value().message.is_undefined())
    assert_false(Bool(receive_message_on_port(channel.port2)))

    var builder = _JsValueBuilder()
    var root = builder.append_array(List[Int]())
    var children = List[Int](capacity=2)
    children.append(root)
    children.append(root)
    builder.set_aggregate_children(root, children^)
    var source = builder.value(root)
    channel.port1.post_message(source)
    var clone = receive_message_on_port(channel.port2).value().message
    assert_false(source.same_identity(clone))
    assert_true(clone.same_identity(clone.array_at(0)))
    assert_true(clone.array_at(0).same_identity(clone.array_at(1)))
    var count = Location(0)
    var created = Location(Optional[MessageChannel]())
    _ = channel.port2.on_callable1(
        JsValue(JsString("message")), callback(count, created)
    )
    channel.port1.post_message(JsValue(1.0))
    _ = receive_message_on_port(channel.port2)
    assert_false(poll_worker_threads())
    assert_equal(count.read(), 0)
    channel.port1.post_message(JsValue(2.0))
    assert_true(poll_worker_threads())
    assert_equal(count.read(), 1)
    assert_true(poll_worker_threads())
    assert_equal(count.read(), 2)
    channel.port1.close()
    channel.port2.close()
    var created_channel = created.read().value()
    created_channel.port1.close()
    created_channel.port2.close()

    var failing = message_channel_new()
    var sibling = message_channel_new()
    _ = failing.port2.on_callable1(
        JsValue(JsString("message")), callback(count, created, True)
    )
    _ = sibling.port2.on_callable1(
        JsValue(JsString("message")), callback(count, created)
    )
    failing.port1.post_message(JsValue(3.0))
    sibling.port1.post_message(JsValue(4.0))
    var rejected = False
    try:
        _ = poll_worker_threads()
    except error:
        rejected = (
            String(error).find("deliberate message callback failure") >= 0
        )
    assert_true(rejected)
    assert_equal(count.read(), 3)
    assert_true(poll_worker_threads())
    assert_equal(count.read(), 4)
    failing.port1.close()
    failing.port2.close()
    sibling.port1.close()
    sibling.port2.close()
    _ = poll_worker_threads()
    mark_as_untransferable(JsValue(1.0))
    assert_false(is_marked_as_untransferable(JsValue(1.0)))
    mark_as_untransferable(source)
    assert_true(is_marked_as_untransferable(source))
    assert_false(is_marked_as_untransferable(clone))
