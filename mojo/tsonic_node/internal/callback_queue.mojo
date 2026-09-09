from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment


comptime Notification = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct _Invocation[Arguments: Copyable]:
    var callback: RaisingCallable[Arguments, NoneType]
    var arguments: Arguments

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var invocation = context.unsafe_bitcast[Self]()
        invocation[].callback.call(invocation[].arguments.copy())

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


struct CallbackQueue(ImplicitlyCopyable):
    var _pending: ArcPointer[List[Notification]]
    var _limit: Int

    def __init__(out self, limit: Int):
        self._pending = ArcPointer(List[Notification]())
        self._limit = limit

    def require_capacity(self) raises:
        if len(self._pending[]) >= self._limit:
            raise Error("Pending callbacks exceed the finite runtime limit")

    def has_pending(self) -> Bool:
        return len(self._pending[]) != 0

    def pending_count(self) -> Int:
        return len(self._pending[])

    def push(self, notification: Notification) raises:
        self.require_capacity()
        self._pending[].append(notification)

    def defer[Arguments: Copyable](
        self, callback: RaisingCallable[Arguments, NoneType], var arguments: Arguments,
    ) raises:
        self.require_capacity()
        var environment = allocate_callable_environment(
            _Invocation[Arguments](callback, arguments^), _Invocation[Arguments].destroy,
        )
        self.push(Notification(environment, _Invocation[Arguments].invoke))

    def poll(self) raises -> Bool:
        if not self.has_pending():
            return False
        var pending = List[Notification]()
        swap(self._pending[], pending)
        for index in range(len(pending)):
            try:
                pending[index].call(())
            except error:
                var retained = List[Notification]()
                for next_index in range(index + 1, len(pending)):
                    retained.append(pending[next_index])
                for entry in self._pending[]:
                    retained.append(entry)
                self._pending[] = retained^
                raise error
        return True
