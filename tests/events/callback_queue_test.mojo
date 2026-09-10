from std.testing import assert_equal, assert_true, assert_false
from tsonic_runtime import Location, ErasedCallableContext, RaisingCallable, allocate_callable_environment, destroy_callable_environment
from tsonic_node.internal.callback_queue import CallbackQueue, Notification


@fieldwise_init
struct Action:
    var trace: Location[String]
    var queue: CallbackQueue
    var name: String
    var fail: Bool
    var enqueue: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Action]()
        action[].trace.write(action[].trace.read() + action[].name)
        if action[].enqueue:
            action[].queue.push(notification(action[].trace, action[].queue, "C"))
        if action[].fail:
            raise Error("deliberate callback failure")

    @staticmethod
    def typed(context: ErasedCallableContext, var arguments: Tuple[String]) raises:
        var action = context.unsafe_bitcast[Self]()
        action[].trace.write(action[].trace.read() + arguments[0])

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Action](context)


def notification(trace: Location[String], queue: CallbackQueue, name: String, fail: Bool = False, enqueue: Bool = False) -> Notification:
    var environment = allocate_callable_environment(Action(trace, queue, name, fail, enqueue), Action.destroy)
    return Notification(environment, Action.invoke)


def main() raises:
    var queue = CallbackQueue(4)
    var trace = Location(String())
    queue.push(notification(trace, queue, "A", True, True))
    queue.push(notification(trace, queue, "B"))
    var rejected = False
    try:
        _ = queue.poll()
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(trace.read(), "A")
    assert_true(queue.poll())
    assert_equal(trace.read(), "ABC")
    assert_false(queue.has_pending())
    assert_false(queue.poll())

    var bounded = CallbackQueue(1)
    bounded.push(notification(trace, bounded, "D"))
    rejected = False
    try:
        bounded.push(notification(trace, bounded, "X"))
    except:
        rejected = True
    assert_true(rejected)
    assert_true(bounded.poll())
    assert_equal(trace.read(), "ABCD")

    var reserved = bounded.reserve()
    var alias = reserved
    var environment = allocate_callable_environment(Action(trace, bounded, "unused", False, False), Action.destroy)
    var typed = RaisingCallable[Tuple[String], NoneType](environment, Action.typed)
    rejected = False
    try:
        bounded.defer(typed, ("not-accepted",))
    except:
        rejected = True
    assert_true(rejected)
    assert_false(bounded.has_pending())
    reserved.defer(typed, ("E",))
    assert_equal(trace.read(), "ABCD")
    rejected = False
    try:
        alias.defer(typed, ("duplicate",))
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(bounded.pending_count(), 1)
    assert_true(bounded.poll())
    assert_equal(trace.read(), "ABCDE")
    assert_false(bounded.has_pending())
