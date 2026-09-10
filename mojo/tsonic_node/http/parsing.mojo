from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from ..buffer import Buffer
from .messages import IncomingMessage


struct _ParserState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var complete: Bool

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle
        self.complete = False

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_http_parser_free", NoneType](
                self.handle.value()
            )


struct RequestParser(ImplicitlyCopyable):
    var _state: ArcPointer[_ParserState]

    def __init__(out self) raises:
        var handle = external_call[
            "tsonic_node_http_parser_new",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ]()
        if not handle:
            raise Error("Unable to allocate HTTP request parser")
        self._state = ArcPointer(_ParserState(handle))

    def feed(self, bytes: List[Byte], count: Int) raises -> Bool:
        if count < 0 or count > len(bytes):
            raise Error("HTTP parser input length is outside its buffer")
        var status = external_call["tsonic_node_http_parser_feed", c_int](
            self._state[].handle.value(),
            bytes.unsafe_ptr(),
            c_size_t(count),
        )
        if status < 0:
            var message = external_call[
                "tsonic_node_http_parser_error",
                OptionalPointer[UInt8, ImmUntrackedOrigin],
            ](self._state[].handle.value())
            raise Error(
                String(
                    unsafe_from_utf8_ptr=message.value()
                ) if message else "Invalid HTTP request"
            )
        self._state[].complete = status == 1
        return self._state[].complete

    def message(self) raises -> IncomingMessage:
        if not self._state[].complete:
            raise Error("HTTP request is not complete")
        var method = external_call[
            "tsonic_node_http_parser_method", Pointer[UInt8, ImmUntrackedOrigin]
        ](self._state[].handle.value())
        var url = external_call[
            "tsonic_node_http_parser_url", Pointer[UInt8, ImmUntrackedOrigin]
        ](self._state[].handle.value())
        var length = c_size_t(0)
        var pointer = external_call[
            "tsonic_node_http_parser_body",
            OptionalPointer[Byte, ImmUntrackedOrigin],
        ](self._state[].handle.value(), Pointer(to=length))
        var bytes = List[Byte](capacity=Int(length))
        for index in range(Int(length)):
            bytes.append(pointer.value()[index])
        return IncomingMessage(
            String(unsafe_from_utf8_ptr=method),
            String(unsafe_from_utf8_ptr=url),
            Buffer(bytes^),
        )
