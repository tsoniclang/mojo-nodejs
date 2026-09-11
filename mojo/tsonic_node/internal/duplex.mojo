from std.memory import ArcPointer
from tsonic_runtime import RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from tsonic_runtime.callable import ErasedCallableEnvironment
from ..buffer import Buffer


struct Duplex(ImplicitlyCopyable):
    var _identity: UInt
    var _read: RaisingCallable[Tuple[], Optional[Buffer]]
    var _write: RaisingCallable[Tuple[Buffer], Bool]
    var _end: RaisingCallable[Tuple[Optional[Buffer]], NoneType]

    def __init__(out self, identity: UInt, environment: ArcPointer[ErasedCallableEnvironment], read: def(ErasedCallableContext, var Tuple[]) thin raises -> Optional[Buffer], write: def(ErasedCallableContext, var Tuple[Buffer]) thin raises -> Bool, end: def(ErasedCallableContext, var Tuple[Optional[Buffer]]) thin raises -> None):
        self._identity = identity
        self._read = RaisingCallable[Tuple[], Optional[Buffer]](environment, read)
        self._write = RaisingCallable[Tuple[Buffer], Bool](environment, write)
        self._end = RaisingCallable[Tuple[Optional[Buffer]], NoneType](environment, end)

    def read(self) raises -> Optional[Buffer]:
        return self._read.call(())

    def write_buffer(self, value: Buffer) raises -> Bool:
        return self._write.call((value,))

    def write_string(self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def end(self) raises -> Self:
        self._end.call((Optional[Buffer](),))
        return self

    def end_buffer(self, value: Buffer) raises -> Self:
        self._end.call((Optional(value),))
        return self

    def end_string(self, value: String) raises -> Self:
        return self.end_buffer(Buffer.from_string(value))

    def same(self, other: Self) -> Bool:
        return self._identity == other._identity


@fieldwise_init
struct _DuplexAdapter[Stream: ImplicitlyCopyable]:
    var stream: Self.Stream
    var read: def(mut Self.Stream) thin raises -> Optional[Buffer]
    var write: def(mut Self.Stream, Buffer) thin raises -> Bool
    var end: def(mut Self.Stream, Optional[Buffer]) thin raises -> None

    @staticmethod
    def read_value(context: ErasedCallableContext, var arguments: Tuple[]) raises -> Optional[Buffer]:
        _ = arguments
        var owner = context.unsafe_bitcast[Self]()
        var read = owner[].read
        return read(owner[].stream)

    @staticmethod
    def write_value(context: ErasedCallableContext, var arguments: Tuple[Buffer]) raises -> Bool:
        var owner = context.unsafe_bitcast[Self]()
        var write = owner[].write
        return write(owner[].stream, arguments[0])

    @staticmethod
    def end_value(context: ErasedCallableContext, var arguments: Tuple[Optional[Buffer]]) raises:
        var owner = context.unsafe_bitcast[Self]()
        var end = owner[].end
        end(owner[].stream, arguments[0])


def create_duplex[Stream: ImplicitlyCopyable](stream: Stream, identity: UInt, read: def(mut Stream) thin raises -> Optional[Buffer], write: def(mut Stream, Buffer) thin raises -> Bool, end: def(mut Stream, Optional[Buffer]) thin raises -> None) -> Duplex:
    comptime Adapter = _DuplexAdapter[Stream]
    var environment = allocate_callable_environment(Adapter(stream, read, write, end), destroy_callable_environment[Adapter])
    return Duplex(identity, environment, Adapter.read_value, Adapter.write_value, Adapter.end_value)
