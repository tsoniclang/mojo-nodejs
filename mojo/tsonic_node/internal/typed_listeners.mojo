from std.collections import List
from std.memory import ArcPointer
from std.builtin.rebind import downcast, rebind_var
from tsonic_runtime import RaisingCallable


@fieldwise_init
struct _Listener[Arguments: Movable & Deinitable](ImplicitlyCopyable):
    var identity: UInt64
    var callback: RaisingCallable[Self.Arguments, NoneType]
    var fired: Optional[ArcPointer[Bool]]


@fieldwise_init
struct _Listeners[Arguments: Movable & Deinitable]:
    var entries: List[_Listener[Self.Arguments]]
    var next_identity: UInt64


struct TypedListeners[Arguments: AnyType](ImplicitlyCopyable):
    comptime Payload = downcast[Self.Arguments, Movable & Deinitable]

    var _state: ArcPointer[_Listeners[Self.Payload]]

    def __init__(
        out self,
    ) where conforms_to(Self.Arguments, Movable & Deinitable):
        self._state = ArcPointer(
            _Listeners[Self.Payload](List[_Listener[Self.Payload]](), 0)
        )

    def has_listeners(self) -> Bool:
        return len(self._state[].entries) != 0

    def add(
        self,
        callback: RaisingCallable[Self.Arguments, NoneType],
        once: Bool = False,
    ) raises where conforms_to(Self.Arguments, Movable & Deinitable):
        if len(
            self._state[].entries
        ) >= 1048576 or self._state[].next_identity == UInt64(
            18446744073709551615
        ):
            raise Error("Event listeners exceed the finite runtime limit")
        self._state[].next_identity += 1
        var fired = Optional[ArcPointer[Bool]](
            ArcPointer(False)
        ) if once else Optional[ArcPointer[Bool]]()
        self._state[].entries.append(
            _Listener[Self.Payload](
                self._state[].next_identity,
                rebind_var[RaisingCallable[Self.Payload, NoneType]](callback),
                fired,
            )
        )

    def remove(
        self, callback: RaisingCallable[Self.Arguments, NoneType]
    ) where conforms_to(Self.Arguments, Movable & Deinitable):
        var found = -1
        var selected = rebind_var[RaisingCallable[Self.Payload, NoneType]](
            callback
        )
        for index in range(len(self._state[].entries)):
            if self._state[].entries[index].callback.same(selected):
                found = index
        if found < 0:
            return
        var retained = List[_Listener[Self.Payload]]()
        for index in range(len(self._state[].entries)):
            if index != found:
                retained.append(self._state[].entries[index])
        self._state[].entries = retained^

    def emit(
        self, arguments: Self.Arguments
    ) raises -> Bool where conforms_to(Self.Arguments, Copyable & Deinitable):
        var snapshot = self._state[].entries.copy()
        for listener in snapshot:
            if listener.fired:
                if listener.fired.value()[]:
                    continue
                listener.fired.value()[] = True
                var retained = List[_Listener[Self.Payload]]()
                for current in self._state[].entries:
                    if current.identity != listener.identity:
                        retained.append(current)
                self._state[].entries = retained^
            listener.callback.call(rebind_var[Self.Payload](arguments.copy()))
        return len(snapshot) != 0
