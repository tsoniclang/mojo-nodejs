from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsString, JsValue
from tsonic_runtime import ErasedCallableContext, Location, RaisingCallable, allocate_callable_environment, destroy_callable_environment
from tsonic_node.worker_threads import message_channel_new, poll_worker_threads
from tsonic_node.worker_threads.ports import MessagePort, PortState, _ports, has_active_worker_threads


@fieldwise_init
struct CountEnvironment:
    var count: Location[Int]
    var fail: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[JsValue]) raises:
        var environment = context.unsafe_bitcast[CountEnvironment]()
        environment[].count.write(environment[].count.read() + 1)
        if environment[].fail:
            raise Error("port ownership callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[CountEnvironment](context)


def listener(count: Location[Int], fail: Bool = False) -> RaisingCallable[Tuple[JsValue], NoneType]:
    var environment = allocate_callable_environment(CountEnvironment(count, fail), CountEnvironment.destroy)
    return RaisingCallable[Tuple[JsValue], NoneType](environment, CountEnvironment.invoke)


def dropped_pair() raises -> Tuple[WeakPointer[PortState], WeakPointer[PortState]]:
    var channel = message_channel_new()
    channel.port1.post_message(JsValue(42.0))
    return (WeakPointer[PortState](downgrade=channel.port1._state), WeakPointer[PortState](downgrade=channel.port2._state))


def dropped_peer() raises -> Tuple[WeakPointer[PortState], MessagePort]:
    var channel = message_channel_new()
    return (WeakPointer[PortState](downgrade=channel.port1._state), channel.port2)


def active_listener(count: Location[Int], unreference: Bool = False, remove: Bool = False, fail: Bool = False) raises -> WeakPointer[PortState]:
    var channel = message_channel_new()
    var callback = listener(count, fail)
    var event = JsValue(JsString("message"))
    _ = channel.port2.once_callable1(event, callback)
    channel.port1.post_message(JsValue(1.0))
    if unreference:
        _ = channel.port2.unref_chain()
    if remove:
        _ = channel.port2.off_callable1(event, callback)
    return WeakPointer[PortState](downgrade=channel.port2._state)


def close_notification(count: Location[Int]) raises -> WeakPointer[PortState]:
    var channel = message_channel_new()
    _ = channel.port2.once_callable1(JsValue(JsString("close")), listener(count))
    channel.port2.close()
    return WeakPointer[PortState](downgrade=channel.port2._state)


def main() raises:
    var pair = dropped_pair()
    assert_equal(pair[0].strong_count(), 0)
    assert_equal(pair[1].strong_count(), 0)
    assert_false(has_active_worker_threads())
    var peer = dropped_peer()
    assert_equal(peer[0].strong_count(), 0)
    assert_true(peer[1]._state[].channel.closed())
    assert_true(poll_worker_threads())
    assert_true(peer[1]._state[].close_emitted)
    var count = Location(0)
    var active = active_listener(count)
    assert_true(active.strong_count() != 0)
    assert_true(has_active_worker_threads())
    assert_true(poll_worker_threads())
    assert_equal(count.read(), 1)
    assert_equal(active.strong_count(), 0)
    assert_false(has_active_worker_threads())
    var unreferenced = active_listener(count, unreference=True)
    assert_equal(unreferenced.strong_count(), 0)
    var removed = active_listener(count, remove=True)
    assert_equal(removed.strong_count(), 0)
    var closing = close_notification(count)
    assert_true(closing.strong_count() != 0)
    assert_true(has_active_worker_threads())
    assert_true(poll_worker_threads())
    assert_equal(count.read(), 2)
    assert_equal(closing.strong_count(), 0)
    var failing = active_listener(count, fail=True)
    var rejected = False
    try:
        _ = poll_worker_threads()
    except error:
        rejected = String(error).find("port ownership callback failure") >= 0
    assert_true(rejected)
    assert_equal(count.read(), 3)
    assert_equal(failing.strong_count(), 0)
    assert_false(has_active_worker_threads())
    for _ in range(4096):
        var unused = dropped_pair()
        assert_equal(unused[0].strong_count(), 0)
        assert_equal(unused[1].strong_count(), 0)
    assert_true(len(_ports.get()[]) <= 1024)
    assert_false(poll_worker_threads())
