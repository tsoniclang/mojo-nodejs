from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from ..buffer import Buffer


struct _ReadOwner(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_stream_read_drop", NoneType](
                self.handle.value()
            )


struct NativeRead(ImplicitlyCopyable):
    var _owner: ArcPointer[_ReadOwner]

    def __init__(
        out self, descriptor: Int32, size: Int, offset: Optional[Int64]
    ) raises:
        var status = c_int(0)
        var handle = external_call[
            "tsonic_node_stream_read_start",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](
            c_int(descriptor),
            c_size_t(size),
            offset.value() if offset else Int64(0),
            c_int(Bool(offset)),
            Pointer(to=status),
        )
        if not handle:
            raise Error("Unable to start bounded stream read: ", status)
        self._owner = ArcPointer(_ReadOwner(handle))

    def ready(self) -> Bool:
        _ = external_call["tsonic_node_stream_read_poll", c_int]()
        return (
            external_call["tsonic_node_stream_read_ready", c_int](
                self._owner[].handle.value()
            )
            != 0
        )

    def result(self) raises -> Optional[Buffer]:
        if not self.ready():
            raise Error("Asynchronous stream read is not complete")
        var count = external_call["tsonic_node_stream_read_result", Int64](
            self._owner[].handle.value()
        )
        if count < 0:
            var message = external_call[
                "tsonic_node_stream_read_error",
                OptionalPointer[UInt8, ImmUntrackedOrigin],
            ](self._owner[].handle.value())
            if not message:
                raise Error("Asynchronous stream read lost its error result")
            raise Error(String(unsafe_from_utf8_ptr=message.value()))
        if count == 0:
            return None
        if count > 1048576:
            raise Error(
                "Asynchronous stream read exceeded its exact buffer extent"
            )
        var bytes = List[Byte](capacity=Int(count))
        for _ in range(Int(count)):
            bytes.append(0)
        var status = external_call["tsonic_node_stream_read_copy", c_int](
            self._owner[].handle.value(),
            bytes.unsafe_ptr(),
            c_size_t(count),
        )
        if status != 0:
            raise Error("Asynchronous stream read lost its exact byte result")
        return Buffer(bytes^)
