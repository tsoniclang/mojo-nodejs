from std.testing import assert_equal, assert_false, assert_true
from tsonic_runtime import Location, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_node.internal.callback_queue import CallbackQueue, Notification


@fieldwise_init
struct Action:
    var queue: CallbackQueue
    var trace: Location[String]
    var name: String
    var enqueue: Bool
    var fail: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + action[].name)
        if action[].enqueue:
            action[].queue.push(notification(action[].queue, action[].trace, "C"))
            var rejected = False
            try:
                action[].queue.push(notification(action[].queue, action[].trace, "overflow"))
            except:
                rejected = True
            assert_true(rejected)
            assert_false(action[].queue.poll())
        if action[].fail:
            raise Error("callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def notification(queue: CallbackQueue, trace: Location[String], name: String,
                 enqueue: Bool = False, fail: Bool = False) -> Notification:
    var context = allocate_callable_environment(Action(queue, trace, name, enqueue, fail), Action.destroy)
    return Notification(context, Action.invoke)


def abandoned_reservation(queue: CallbackQueue) raises:
    var reservation = queue.reserve()
    var rejected = False
    try:
        queue.require_capacity()
    except:
        rejected = True
    assert_true(rejected)
    _ = reservation._state[].active


def main() raises:
    var queue = CallbackQueue(2)
    var trace = Location(String())
    var first = queue.reserve()
    var second = queue.reserve()
    assert_false(queue.has_pending())
    var rejected = False
    try:
        queue.push(notification(queue, trace, "overflow"))
    except:
        rejected = True
    assert_true(rejected)
    first.commit(notification(queue, trace, "A", True, True))
    second.commit(notification(queue, trace, "B"))
    rejected = False
    try:
        first.commit(notification(queue, trace, "duplicate"))
    except:
        rejected = True
    assert_true(rejected)
    rejected = False
    try:
        _ = queue.poll()
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(trace.read(), "A")
    assert_equal(queue.pending_count(), 2)
    assert_true(queue.poll())
    assert_equal(trace.read(), "ABC")
    assert_false(queue.has_pending())
    var bounded = CallbackQueue(1)
    abandoned_reservation(bounded)
    bounded.push(notification(bounded, trace, "D"))
    assert_true(bounded.poll())
    assert_equal(trace.read(), "ABCD")
