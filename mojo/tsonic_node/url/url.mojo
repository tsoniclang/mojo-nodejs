from std.memory import ArcPointer
from std.ffi import c_int, c_size_t, external_call, get_errno
from .state import UrlState, create_url_state, get_url_field, set_url_field
from .params import URLSearchParams


struct URL(Equatable, ImplicitlyCopyable):
    var _state: ArcPointer[UrlState]

    def __init__(out self, input: String, base: Optional[String] = None) raises:
        self._state = create_url_state(input, base)

    def __eq__(self, other: Self) -> Bool:
        return self._state is other._state

    def href(self) raises -> String:
        return get_url_field(self._state, 0)

    def set_href(self, value: String) raises:
        set_url_field(self._state, 0, value)

    def protocol(self) raises -> String:
        return get_url_field(self._state, 1)

    def set_protocol(self, value: String) raises:
        set_url_field(self._state, 1, value)

    def username(self) raises -> String:
        return get_url_field(self._state, 2)

    def set_username(self, value: String) raises:
        set_url_field(self._state, 2, value)

    def password(self) raises -> String:
        return get_url_field(self._state, 3)

    def set_password(self, value: String) raises:
        set_url_field(self._state, 3, value)

    def host(self) raises -> String:
        return get_url_field(self._state, 4)

    def set_host(self, value: String) raises:
        set_url_field(self._state, 4, value)

    def hostname(self) raises -> String:
        return get_url_field(self._state, 5)

    def set_hostname(self, value: String) raises:
        set_url_field(self._state, 5, value)

    def port(self) raises -> String:
        return get_url_field(self._state, 6)

    def set_port(self, value: String) raises:
        set_url_field(self._state, 6, value)

    def pathname(self) raises -> String:
        return get_url_field(self._state, 7)

    def set_pathname(self, value: String) raises:
        set_url_field(self._state, 7, value)

    def search(self) raises -> String:
        return get_url_field(self._state, 8)

    def set_search(self, value: String) raises:
        set_url_field(self._state, 8, value)

    def hash(self) raises -> String:
        return get_url_field(self._state, 9)

    def set_hash(self, value: String) raises:
        set_url_field(self._state, 9, value)

    def origin(self) raises -> String:
        return get_url_field(self._state, 10)

    def search_params(self) -> URLSearchParams:
        return URLSearchParams(state=self._state)

    def to_string(self) raises -> String:
        return self.href()


def url_new(input: String) raises -> URL:
    return URL(input)


def url_new(input: String, base: String) raises -> URL:
    return URL(input, Optional(base))


def url_new(input: String, base: URL) raises -> URL:
    return URL(input, Optional(base.href()))


def can_parse(input: String) raises -> Bool:
    return _can_parse(input, None)


def can_parse(input: String, base: String) raises -> Bool:
    return _can_parse(input, Optional(base))


def can_parse(input: String, base: URL) raises -> Bool:
    return can_parse(input, base.href())


def _can_parse(input: String, base: Optional[String]) raises -> Bool:
    var base_text = base.value() if base else String()
    var result = external_call["tsonic_node_url_can_parse", c_int](
        input.as_bytes().unsafe_ptr(),
        c_size_t(input.byte_length()),
        base_text.as_bytes().unsafe_ptr(),
        c_size_t(base_text.byte_length()),
        c_int(Bool(base)),
    )
    if result < 0:
        raise Error("Unable to validate URL: ", get_errno())
    return result != 0


def url_parse(input: String) raises -> Optional[URL]:
    if not can_parse(input):
        return None
    return URL(input)


def url_parse(input: String, base: String) raises -> Optional[URL]:
    if not can_parse(input, base):
        return None
    return URL(input, Optional(base))


def url_parse(input: String, base: URL) raises -> Optional[URL]:
    return url_parse(input, base.href())
