from std.collections import Span
from std.ffi import c_char, c_int, c_size_t, external_call, get_errno
from std.memory import ArcPointer


struct UrlState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_url_free", NoneType](self.handle.value())


def create_url_state(input: String, base: Optional[String]) raises -> ArcPointer[UrlState]:
    var base_text = base.value() if base else String()
    var handle = external_call["tsonic_node_url_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
        input.as_bytes().unsafe_ptr(), c_size_t(input.byte_length()),
        base_text.as_bytes().unsafe_ptr(), c_size_t(base_text.byte_length()), c_int(Bool(base)),
    )
    if not handle:
        raise Error("Unable to parse URL: ", get_errno())
    return ArcPointer(UrlState(handle))


def create_params_state(input: String) raises -> ArcPointer[UrlState]:
    var handle = external_call["tsonic_node_url_params_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
        input.as_bytes().unsafe_ptr(), c_size_t(input.byte_length()),
    )
    if not handle:
        raise Error("Unable to parse URLSearchParams: ", get_errno())
    return ArcPointer(UrlState(handle))


def get_url_field(state: ArcPointer[UrlState], field: Int32) raises -> String:
    var length = c_size_t(0)
    var text = external_call["tsonic_node_url_get", OptionalPointer[c_char, ImmutUntrackedOrigin]](
        state[].handle.value(), c_int(field), Pointer(to=length),
    )
    if not text:
        raise Error("Unable to read URL: ", get_errno())
    return String(unsafe_from_utf8=Span(unsafe_ptr=text.value().unsafe_bitcast[Byte](), length=Int(length)))


def set_url_field(state: ArcPointer[UrlState], field: Int32, value: String) raises:
    if external_call["tsonic_node_url_set", c_int](
        state[].handle.value(), c_int(field), value.as_bytes().unsafe_ptr(), c_size_t(value.byte_length()),
    ) != 0:
        raise Error("Unable to update URL: ", get_errno())
