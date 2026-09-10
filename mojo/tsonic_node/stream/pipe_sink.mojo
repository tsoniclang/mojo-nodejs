from std.variant import Variant
from ..buffer import Buffer
from ..http import ServerResponse
from .chunk import StreamChunk
from .writable import Writable


comptime PipeTarget = Variant[Writable, ServerResponse]


struct PipeSink(ImplicitlyCopyable):
    var target: PipeTarget
    var waiting: Bool

    def __init__(out self, value: Writable):
        self.target = PipeTarget(value)
        self.waiting = False

    def __init__(out self, value: ServerResponse):
        self.target = PipeTarget(value)
        self.waiting = False

    def writable(self) -> Bool:
        if self.target.isa[Writable]():
            return self.target.unsafe_get[Writable]().writable()
        var response = self.target.unsafe_get[ServerResponse]()
        return not response.is_finished() and not response.is_drained()

    def ready(mut self) -> Bool:
        if self.waiting and self.target.isa[Writable]():
            self.waiting = self.target.unsafe_get[Writable]().pipe_needs_drain()
        return not self.waiting

    def write(mut self, value: StreamChunk) raises:
        if self.target.isa[Writable]():
            self.waiting = not self.target.unsafe_get[Writable]().write_value(value)
        elif value.isa[Buffer]():
            _ = self.target.unsafe_get[ServerResponse]().write_buffer(value.unsafe_get[Buffer]())
        else:
            _ = self.target.unsafe_get[ServerResponse]().write_buffer(Buffer.from_string(value.unsafe_get[String]()))

    def end(mut self) raises:
        if self.target.isa[Writable]():
            self.target.unsafe_get[Writable]().end_from_pipe()
        else:
            self.target.unsafe_get[ServerResponse]().end_empty()
