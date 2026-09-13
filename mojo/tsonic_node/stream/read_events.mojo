from std.collections import Dict
from std.memory import ArcPointer
from tsonic_runtime import (
    RaisingCallable,
    TsError,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from ..internal.callback_queue import Notification, CallbackReservation
from ..internal.typed_listeners import TypedListeners
from .chunk import StreamChunk
from .completion import stream_completions


comptime DataCallback = RaisingCallable[Tuple[StreamChunk], NoneType]
comptime ReadErrorCallback = RaisingCallable[Tuple[TsError], NoneType]


@fieldwise_init
struct _ReadEventState:
    var data: TypedListeners[Tuple[StreamChunk]]
    var errors: TypedListeners[Tuple[TsError]]
    var notifications: Dict[String, TypedListeners[Tuple[]]]
    var reservations: Dict[String, CallbackReservation]
    var error: Optional[TsError]
    var end_queued: Bool
    var ended: Bool
    var close_queued: Bool
    var closed: Bool


struct ReadEvents(ImplicitlyCopyable):
    var state: ArcPointer[_ReadEventState]

    def __init__(out self):
        self.state = ArcPointer(
            _ReadEventState(
                TypedListeners[Tuple[StreamChunk]](),
                TypedListeners[Tuple[TsError]](),
                Dict[String, TypedListeners[Tuple[]]](),
                Dict[String, CallbackReservation](),
                None,
                False,
                False,
                False,
                False,
            )
        )

    def notifications(self, event: String) raises -> TypedListeners[Tuple[]]:
        if (
            event != "end"
            and event != "close"
            and event != "readable"
            and event != "pause"
            and event != "resume"
        ):
            raise Error("Unsupported readable notification: ", event)
        if event not in self.state[].notifications:
            self.state[].notifications[event] = TypedListeners[Tuple[]]()
        return self.state[].notifications[event]

    def has(self, event: String) -> Bool:
        var listeners = self.state[].notifications.get(event)
        return Bool(listeners) and listeners.value().has_listeners()

    def emit(self, event: String) raises:
        if event in self.state[].notifications:
            _ = self.state[].notifications[event].emit(())

    def prepare(self) raises:
        if self.state[].closed:
            return
        var pending = Dict[String, CallbackReservation]()
        self.prepare_event("end", self.state[].end_queued, pending)
        self.prepare_event("error", Bool(self.state[].error), pending)
        self.prepare_event("close", self.state[].close_queued, pending)
        for event in pending:
            self.state[].reservations[event] = pending[event]

    def prepare_event(
        self,
        event: String,
        committed: Bool,
        mut pending: Dict[String, CallbackReservation],
    ) raises:
        if not committed and event not in self.state[].reservations:
            pending[event] = stream_completions.get()[].reserve()

    def queue(self, event: String) raises:
        if event not in self.state[].reservations:
            raise Error(
                "Readable lifecycle delivery has no reserved queue capacity"
            )
        var reservation = self.state[].reservations.pop(event)
        var environment = allocate_callable_environment(
            _ReadEvent(self, event), destroy_callable_environment[_ReadEvent]
        )
        reservation.commit(Notification(environment, _ReadEvent.invoke))

    def end(self) raises:
        if (
            not self.state[].end_queued
            and not self.state[].close_queued
            and not self.state[].error
        ):
            self.queue("end")
            self.state[].end_queued = True

    def close(self) raises:
        if not self.state[].close_queued:
            self.queue("close")
            self.state[].close_queued = True

    def fail(self, error: TsError) raises:
        if not self.state[].error and not self.state[].closed:
            self.state[].error = error.copy()
            self.queue("error")


@fieldwise_init
struct _ReadEvent:
    var events: ReadEvents
    var event: String

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var invocation = context.unsafe_bitcast[Self]()
        var events = invocation[].events
        var event = invocation[].event
        if event == "error":
            var error = events.state[].error.value().copy()
            if not events.state[].errors.emit((error.copy(),)):
                raise error.native_error()
        elif event == "end":
            if not events.state[].error:
                events.state[].ended = True
                events.emit(event)
        elif event == "close":
            events.state[].closed = True
            events.state[].reservations.clear()
            events.emit(event)
