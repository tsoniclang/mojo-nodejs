from std.testing import assert_equal, assert_false, assert_true
from std.memory import ArcPointer
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    TsError,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.internal.typed_listeners import TypedListeners


comptime Notification = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct Action:
    var trace: Location[String]
    var name: String
    var listeners: TypedListeners[Tuple[]]
    var remove: Optional[Notification]
    var recurse: Location[Bool]

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var action = context.unsafe_bitcast[Action]()
        action[].trace.write(action[].trace.read() + action[].name)
        if action[].remove:
            action[].listeners.remove(action[].remove.value())
        if action[].recurse.read():
            action[].recurse.write(False)
            _ = action[].listeners.emit(())

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Action](context)


def callback(
    trace: Location[String],
    name: String,
    listeners: TypedListeners[Tuple[]],
    remove: Optional[Notification] = None,
    recurse: Bool = False,
) -> Notification:
    var environment = allocate_callable_environment(
        Action(trace, name, listeners, remove, Location(recurse)),
        Action.destroy,
    )
    return Notification(environment, Action.invoke)


struct _RecursiveState:
    var listeners: TypedListeners[Tuple[TsError, RecursiveOwner]]
    var calls: Int

    def __init__(out self):
        self.listeners = TypedListeners[Tuple[TsError, RecursiveOwner]]()
        self.calls = 0


struct RecursiveOwner(ImplicitlyCopyable):
    var state: ArcPointer[_RecursiveState]

    def __init__(out self):
        self.state = ArcPointer(_RecursiveState())

    @staticmethod
    def receive(
        _context: ErasedCallableContext, var arguments: Tuple[TsError, Self]
    ) raises:
        assert_equal(arguments[0].name, "SelectedError")
        assert_equal(arguments[0].message, "exact-payload")
        assert_equal(arguments[0].stack.value(), "exact-stack")
        arguments[1].state[].calls += 1


def recursive_payload() raises:
    var owner = RecursiveOwner()
    var retained_alias = owner
    var environment = allocate_callable_environment(
        0, destroy_callable_environment[Int]
    )
    var callback = RaisingCallable[Tuple[TsError, RecursiveOwner], NoneType](
        environment, RecursiveOwner.receive
    )
    owner.state[].listeners.add(callback)
    owner.state[].listeners.add(callback, True)
    var error = TsError("SelectedError", "exact-payload", String("exact-stack"))
    _ = retained_alias.state[].listeners.emit((error.copy(), owner))
    assert_equal(owner.state[].calls, 2)
    _ = owner.state[].listeners.emit((error.copy(), retained_alias))
    assert_equal(retained_alias.state[].calls, 3)
    retained_alias.state[].listeners.remove(callback)
    assert_false(owner.state[].listeners.has_listeners())


def main() raises:
    recursive_payload()
    var listeners = TypedListeners[Tuple[]]()
    var trace = Location(String())
    var first = callback(trace, "A", listeners)
    var second = callback(trace, "B", listeners)
    listeners.add(first)
    listeners.add(second)
    listeners.add(first)
    listeners.remove(first)
    assert_true(listeners.emit(()))
    assert_equal(trace.read(), "AB")
    listeners.remove(first)
    listeners.remove(second)
    assert_false(listeners.has_listeners())

    trace.write("")
    var nested = callback(trace, "A", listeners, recurse=True)
    var once = callback(trace, "B", listeners)
    listeners.add(nested)
    listeners.add(once, True)
    _ = listeners.emit(())
    assert_equal(trace.read(), "AAB")
    listeners.remove(nested)
    assert_false(listeners.has_listeners())

    trace.write("")
    var removed = callback(trace, "B", listeners)
    var removing = callback(trace, "A", listeners, removed)
    listeners.add(removing)
    listeners.add(removed)
    _ = listeners.emit(())
    assert_equal(trace.read(), "AB")
    _ = listeners.emit(())
    assert_equal(trace.read(), "ABA")
    listeners.remove(removing)
    assert_false(listeners.emit(()))
