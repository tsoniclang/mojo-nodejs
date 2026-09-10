from std.collections import List, Span
from std.ffi import c_char, c_int, c_size_t, external_call, get_errno
from std.memory import ArcPointer
from .state import UrlState, create_params_state, get_url_field


struct URLSearchParams(Equatable, ImplicitlyCopyable, Sized):
    var _state: ArcPointer[UrlState]

    def __init__(out self, input: String = "") raises:
        self._state = create_params_state(input)

    def __init__(out self, *, state: ArcPointer[UrlState]):
        self._state = state

    def __eq__(self, other: Self) -> Bool:
        return self._state is other._state

    def __len__(self) -> Int:
        return Int(external_call["tsonic_node_url_params_size", c_size_t](self._state[].handle.value()))

    def size(self) -> Float64:
        return Float64(len(self))

    def get(self, name: String) -> Optional[String]:
        for index in range(len(self)):
            if self._at(index, True) == name:
                return self._at(index, False)
        return None

    def get_all(self, name: String) -> List[String]:
        var values = List[String]()
        for index in range(len(self)):
            if self._at(index, True) == name:
                values.append(self._at(index, False))
        return values^

    def has(self, name: String) -> Bool:
        return self._has(name, "", False)

    def has(self, name: String, value: String) -> Bool:
        return self._has(name, value, True)

    def _has(self, name: String, value: String, match_value: Bool) -> Bool:
        return external_call["tsonic_node_url_params_has", c_int](
            self._state[].handle.value(), name.as_bytes().unsafe_ptr(), c_size_t(name.byte_length()),
            value.as_bytes().unsafe_ptr(), c_size_t(value.byte_length()), c_int(match_value),
        ) != 0

    def set(self, name: String, value: String) raises:
        self._mutate(1, name, value)

    def append(self, name: String, value: String) raises:
        self._mutate(0, name, value)

    def delete(self, name: String) raises:
        self._mutate(2, name, "")

    def delete(self, name: String, value: String) raises:
        self._mutate(3, name, value)

    def sort(self) raises:
        self._mutate(4, "", "")

    def to_string(self) raises -> String:
        return get_url_field(self._state, 11)

    def _mutate(self, operation: Int32, name: String, value: String) raises:
        if external_call["tsonic_node_url_params_mutate", c_int](
            self._state[].handle.value(), c_int(operation),
            name.as_bytes().unsafe_ptr(), c_size_t(name.byte_length()),
            value.as_bytes().unsafe_ptr(), c_size_t(value.byte_length()),
        ) != 0:
            raise Error("Unable to update URLSearchParams: ", get_errno())

    def _at(self, index: Int, key: Bool) -> String:
        var length = c_size_t(0)
        var text = external_call["tsonic_node_url_params_at", OptionalPointer[c_char, ImmUntrackedOrigin]](
            self._state[].handle.value(), c_size_t(index), c_int(key), Pointer(to=length),
        )
        return String(unsafe_from_utf8=Span(unsafe_ptr=text.value().unsafe_bitcast[Byte](), length=Int(length)))


def search_params_new() raises -> URLSearchParams:
    return URLSearchParams()


def search_params_new(input: String) raises -> URLSearchParams:
    return URLSearchParams(input)
