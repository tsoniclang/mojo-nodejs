from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment


comptime Notification = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct _QueueState:
    var pending: List[Notification]
    var limit: Int
    var committed: Int
    var reserved: Int
    var polling: Bool


struct _ReservationState(Movable):
    var queue: ArcPointer[_QueueState]
    var active: Bool

    def __init__(out self, queue: ArcPointer[_QueueState]):
        self.queue = queue
        self.active = True
        self.queue[].reserved += 1

    def __deinit__(deinit self):
        if self.active:
            self.queue[].reserved -= 1


struct CallbackReservation(ImplicitlyCopyable):
    var _state: ArcPointer[_ReservationState]

    def __init__(out self, queue: ArcPointer[_QueueState]):
        self._state = ArcPointer(_ReservationState(queue))

    def commit(self, callback: Notification) raises:
        if not self._state[].active:
            raise Error("Callback reservation was already consumed")
        self._state[].active = False
        var queue = self._state[].queue
        queue[].reserved -= 1
        queue[].committed += 1
        queue[].pending.append(callback)

    def defer[Arguments: Copyable & Deinitable](
        self, callback: RaisingCallable[Arguments, NoneType], var arguments: Arguments,
    ) raises:
        var environment = allocate_callable_environment(
            _Invocation[Arguments](callback, arguments^), _Invocation[Arguments].destroy,
        )
        self.commit(Notification(environment, _Invocation[Arguments].invoke))


@fieldwise_init
struct _Invocation[Arguments: Copyable & Deinitable]:
    var callback: RaisingCallable[Self.Arguments, NoneType]
    var arguments: Self.Arguments

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var invocation = context.unsafe_bitcast[Self]()
        invocation[].callback.call(invocation[].arguments.copy())

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


struct CallbackQueue(ImplicitlyCopyable):
    var _state: ArcPointer[_QueueState]

    def __init__(out self, limit: Int):
        self._state = ArcPointer(_QueueState(List[Notification](), limit, 0, 0, False))

    def require_capacity(self) raises:
        if self._state[].committed + self._state[].reserved >= self._state[].limit:
            raise Error("Pending callbacks exceed the finite runtime limit")

    def reserve(self) raises -> CallbackReservation:
        self.require_capacity()
        return CallbackReservation(self._state)

    def has_pending(self) -> Bool:
        return len(self._state[].pending) != 0

    def pending_count(self) -> Int:
        return len(self._state[].pending)

    def push(self, notification: Notification) raises:
        self.reserve().commit(notification)

    def defer[Arguments: Copyable & Deinitable](
        self, callback: RaisingCallable[Arguments, NoneType], var arguments: Arguments,
    ) raises:
        self.reserve().defer(callback, arguments^)

    def poll(self) raises -> Bool:
        if self._state[].polling or not self.has_pending():
            return False
        self._state[].polling = True
        try:
            self._poll_batch()
        finally:
            self._state[].polling = False
        return True

    def _poll_batch(self) raises:
        var pending = List[Notification]()
        swap(self._state[].pending, pending)
        for index in range(len(pending)):
            self._state[].committed -= 1
            try:
                pending[index].call(())
            except error:
                var retained = List[Notification]()
                for next_index in range(index + 1, len(pending)):
                    retained.append(pending[next_index])
                for entry in self._state[].pending:
                    retained.append(entry)
                self._state[].pending = retained^
                raise error
