from std.utils import Variant
from std.memory import ArcPointer
from tsonic_runtime import ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from ..internal.callback_queue import Notification
from ..buffer import Buffer
from ..http import ServerResponse
from .chunk import StreamChunk
from .writable import Writable
from .read_events import DataCallback


comptime PipeTarget = Variant[Writable, ServerResponse]


@fieldwise_init
struct _PipeState:
    var target: PipeTarget
    var waiting: Bool


struct PipeSink(ImplicitlyCopyable):
    var state: ArcPointer[_PipeState]

    def __init__(out self, value: Writable):
        self.state = ArcPointer(_PipeState(PipeTarget(value), False))

    def __init__(out self, value: ServerResponse):
        self.state = ArcPointer(_PipeState(PipeTarget(value), False))

    def writable(self) -> Bool:
        if self.state[].target.isa[Writable]():
            return self.state[].target.unsafe_get[Writable]().writable()
        var response = self.state[].target.unsafe_get[ServerResponse]()
        return not response.is_finished() and not response.is_drained()

    def ready(self) -> Bool:
        if self.state[].waiting and self.state[].target.isa[Writable]():
            self.state[].waiting = self.state[].target.unsafe_get[Writable]().pipe_needs_drain()
        return not self.state[].waiting

    def write(mut self, value: StreamChunk) raises:
        if not self.writable():
            return
        if self.state[].target.isa[Writable]():
            self.state[].waiting = not self.state[].target.unsafe_get[Writable]().write_value(value)
        elif value.isa[Buffer]():
            _ = self.state[].target.unsafe_get[ServerResponse]().write_buffer(value.unsafe_get[Buffer]())
        else:
            _ = self.state[].target.unsafe_get[ServerResponse]().write_buffer(Buffer.from_string(value.unsafe_get[String]()))

    def end(mut self) raises:
        if not self.writable():
            return
        if self.state[].target.isa[Writable]():
            self.state[].target.unsafe_get[Writable]().end_from_pipe()
        else:
            self.state[].target.unsafe_get[ServerResponse]().end_empty()


struct PipeSubscription(ImplicitlyCopyable):
    var sink: PipeSink
    var data: DataCallback
    var end: Notification

    def __init__(out self, sink: PipeSink):
        self.sink = sink
        var environment = allocate_callable_environment(sink, destroy_callable_environment[PipeSink])
        self.data = DataCallback(environment, Self.write)
        self.end = Notification(environment, Self.finish)

    @staticmethod
    def write(context: ErasedCallableContext, var arguments: Tuple[StreamChunk]) raises:
        var sink = context.unsafe_bitcast[PipeSink]()
        sink[].write(arguments[0].copy())

    @staticmethod
    def finish(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var sink = context.unsafe_bitcast[PipeSink]()
        sink[].end()
