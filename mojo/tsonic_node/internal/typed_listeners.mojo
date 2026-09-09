from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import RaisingCallable


@fieldwise_init
struct _Listener[Arguments: Copyable](ImplicitlyCopyable):
    var identity: UInt64
    var callback: RaisingCallable[Arguments, NoneType]
    var fired: Optional[ArcPointer[Bool]]


@fieldwise_init
struct _Listeners[Arguments: Copyable]:
    var entries: List[_Listener[Arguments]]
    var next_identity: UInt64


struct TypedListeners[Arguments: Copyable](ImplicitlyCopyable):
    var _state: ArcPointer[_Listeners[Arguments]]

    def __init__(out self):
        self._state = ArcPointer(_Listeners[Arguments](List[_Listener[Arguments]](), 0))

    def has_listeners(self) -> Bool:
        return len(self._state[].entries) != 0

    def add(self, callback: RaisingCallable[Arguments, NoneType], once: Bool = False) raises:
        if len(self._state[].entries) >= 1048576 or self._state[].next_identity == UInt64(18446744073709551615):
            raise Error("Event listeners exceed the finite runtime limit")
        self._state[].next_identity += 1
        var fired = Optional[ArcPointer[Bool]](ArcPointer(False)) if once else Optional[ArcPointer[Bool]]()
        self._state[].entries.append(_Listener[Arguments](self._state[].next_identity, callback, fired))

    def remove(self, callback: RaisingCallable[Arguments, NoneType]):
        var found = -1
        for index in range(len(self._state[].entries)):
            if self._state[].entries[index].callback.same(callback):
                found = index
        if found < 0:
            return
        var retained = List[_Listener[Arguments]]()
        for index in range(len(self._state[].entries)):
            if index != found:
                retained.append(self._state[].entries[index])
        self._state[].entries = retained^

    def emit(self, arguments: Arguments) raises -> Bool:
        var snapshot = self._state[].entries.copy()
        for listener in snapshot:
            if listener.fired:
                if listener.fired.value()[]:
                    continue
                listener.fired.value()[] = True
                var retained = List[_Listener[Arguments]]()
                for current in self._state[].entries:
                    if current.identity != listener.identity:
                        retained.append(current)
                self._state[].entries = retained^
            listener.callback.call(arguments.copy())
        return len(snapshot) != 0
