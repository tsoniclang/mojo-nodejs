from std.collections import Dict, List
from std.memory import ArcPointer
from tsonic_runtime import (
    TsError,
    error_new,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from ..internal.callback_queue import Notification, CallbackReservation
from ..internal.typed_listeners import TypedListeners
from .completion import StreamCompletion, WriteCallback, stream_completions


@fieldwise_init
struct _WriteEventState:
    var notifications: Dict[String, TypedListeners[Tuple[]]]
    var errors: TypedListeners[Tuple[TsError]]
    var error: Optional[TsError]
    var error_scheduled: Bool
    var finish_scheduled: Bool
    var finished: Bool
    var close_scheduled: Bool
    var close_queued: Bool
    var closed: Bool
    var drain_scheduled: Bool
    var reservations: Dict[String, CallbackReservation]
    var end_completions: List[StreamCompletion]
    var cancelled: Bool


struct WriteEvents(ImplicitlyCopyable):
    var state: ArcPointer[_WriteEventState]

    def __init__(out self):
        self.state = ArcPointer(
            _WriteEventState(
                Dict[String, TypedListeners[Tuple[]]](),
                TypedListeners[Tuple[TsError]](),
                None,
                False,
                False,
                False,
                False,
                False,
                False,
                False,
                Dict[String, CallbackReservation](),
                List[StreamCompletion](),
                False,
            )
        )

    def notifications(self, event: String) raises -> TypedListeners[Tuple[]]:
        if event != "drain" and event != "finish" and event != "close":
            raise Error("Unsupported writable notification: ", event)
        if event not in self.state[].notifications:
            self.state[].notifications[event] = TypedListeners[Tuple[]]()
        return self.state[].notifications[event]

    def prepare(self) raises:
        if self.state[].closed:
            return
        var pending = Dict[String, CallbackReservation]()
        if not self.state[].error_scheduled:
            self._prepare("error", pending)
        if (
            not self.state[].finish_scheduled
            and not self.state[].error
            and not self.state[].cancelled
        ):
            self._prepare("complete", pending)
            self._prepare("finish", pending)
            if not self.state[].drain_scheduled:
                self._prepare("drain", pending)
        if not self.state[].close_scheduled:
            self._prepare("close", pending)
        for event in pending:
            self.state[].reservations[event] = pending[event]

    def _prepare(
        self, event: String, mut pending: Dict[String, CallbackReservation]
    ) raises:
        if event not in self.state[].reservations:
            pending[event] = stream_completions.get()[].reserve()

    def discard(self, event: String) raises:
        if event in self.state[].reservations:
            _ = self.state[].reservations.pop(event)

    def reserve(self, event: String) raises -> CallbackReservation:
        if event not in self.state[].reservations:
            raise Error(
                "Stream lifecycle delivery has no reserved queue capacity"
            )
        return self.state[].reservations.pop(event)

    def queue(self, event: String, reservation: CallbackReservation) raises:
        var environment = allocate_callable_environment(
            _WriteEvent(self, event),
            destroy_callable_environment[_WriteEvent],
        )
        reservation.commit(Notification(environment, _WriteEvent.invoke))

    def retain_end(self, callback: WriteCallback) raises:
        var completion = StreamCompletion(callback)
        if self.state[].error:
            completion.complete(self.state[].error.value().copy())
        elif self.state[].cancelled or self.state[].closed:
            completion.complete(error_new("Cannot end a destroyed stream"))
        elif self.state[].finished:
            completion.complete(
                error_new("Cannot call end after the stream finished")
            )
        else:
            self.state[].end_completions.append(completion)

    def complete_end(self, error: Optional[TsError]) raises:
        var completions = List[StreamCompletion]()
        swap(completions, self.state[].end_completions)
        for completion in completions:
            completion.complete(error)

    def fail(self, error: TsError) raises:
        if self.state[].error_scheduled or self.state[].closed:
            return
        var reservation = self.reserve("error")
        self.state[].error = error.copy()
        self.state[].error_scheduled = True
        self.discard("complete")
        self.discard("finish")
        self.discard("drain")
        self.queue("error", reservation)

    def finish(self) raises:
        if (
            self.state[].finish_scheduled
            or self.state[].error
            or self.state[].cancelled
        ):
            return
        var reservation = self.reserve("complete")
        self.state[].finish_scheduled = True
        self.discard("drain")
        self.queue("complete", reservation)

    def close(self) raises:
        self.state[].close_scheduled = True
        if (
            not self.state[].finish_scheduled
            or self.state[].finished
            or self.state[].error
            or self.state[].cancelled
        ):
            self.queue_close()

    def queue_close(self) raises:
        if not self.state[].close_scheduled or self.state[].close_queued:
            return
        var reservation = self.reserve("close")
        self.state[].close_queued = True
        self.queue("close", reservation)

    def drain(self) raises:
        if (
            self.state[].drain_scheduled
            or self.state[].finish_scheduled
            or self.state[].error
            or self.state[].cancelled
        ):
            return
        var reservation = self.reserve("drain")
        self.state[].drain_scheduled = True
        self.queue("drain", reservation)

    def cancel(self) raises:
        self.state[].cancelled = True
        self.discard("complete")
        self.discard("finish")
        self.discard("drain")


@fieldwise_init
struct _WriteEvent:
    var events: WriteEvents
    var event: String

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var invocation = context.unsafe_bitcast[Self]()
        var events = invocation[].events
        var event = invocation[].event
        if event == "complete":
            if (
                events.state[].error
                or events.state[].closed
                or events.state[].cancelled
            ):
                return
            events.state[].finished = True
            events.complete_end(None)
            events.queue("finish", events.reserve("finish"))
            events.queue_close()
            return
        if event == "error":
            var error = events.state[].error.value().copy()
            if not events.state[].errors.emit((error.copy(),)):
                raise error.native_error()
            return
        if event == "drain":
            events.state[].drain_scheduled = False
            if (
                events.state[].error
                or events.state[].finish_scheduled
                or events.state[].cancelled
            ):
                return
        elif event == "finish":
            if events.state[].error or events.state[].cancelled:
                return
            events.state[].finished = True
        elif event == "close":
            events.state[].closed = True
            events.state[].reservations.clear()
        _ = events.notifications(event).emit(())
