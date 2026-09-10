from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from tsonic_js import JsString, JsValue, js_value_from_object_entries
from .model import LookupAddress


struct RequestOwner(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_dns_request_free", NoneType](self.handle.value())


struct DnsRequest(ImplicitlyCopyable):
    var _owner: ArcPointer[RequestOwner]

    def __init__(out self, input: String, kind: Int32) raises:
        if input.find("\0") >= 0 or input.byte_length() > 4096:
            raise Error("DNS input contains a null byte or exceeds its length limit")
        var handle = OptionalPointer[NoneType, MutUntrackedOrigin]()
        if kind == 0:
            handle = external_call["tsonic_node_dns_lookup_start", OptionalPointer[NoneType, MutUntrackedOrigin]](
                input.as_c_string_slice().ptr().as_unsafe_any_origin(),
            )
        else:
            handle = external_call["tsonic_node_dns_default_query_start", OptionalPointer[NoneType, MutUntrackedOrigin]](
                input.as_c_string_slice().ptr().as_unsafe_any_origin(), kind,
            )
        if not handle:
            raise Error("Unable to allocate a bounded DNS request")
        self._owner = ArcPointer(RequestOwner(handle))

    def ready(self) -> Bool:
        return external_call["tsonic_node_dns_request_ready", c_int](self._owner[].handle.value()) != 0

    def failed(self) -> Bool:
        return external_call["tsonic_node_dns_request_failed", c_int](self._owner[].handle.value()) != 0

    def error_message(self) -> String:
        var message = external_call["tsonic_node_dns_request_error", OptionalPointer[UInt8, ImmUntrackedOrigin]](self._owner[].handle.value())
        return String(unsafe_from_utf8_ptr=message.value()) if message else String("DNS result is not complete")

    def error_code(self) -> String:
        var code = external_call["tsonic_node_dns_request_code", OptionalPointer[UInt8, ImmUntrackedOrigin]](self._owner[].handle.value())
        return String(unsafe_from_utf8_ptr=code.value()) if code else String("EINPROGRESS")

    def error_value(self) raises -> JsValue:
        return js_value_from_object_entries(
            List[JsString](JsString("name"), JsString("message"), JsString("code")),
            List[JsValue](JsValue(JsString("Error")), JsValue(JsString(self.error_message())), JsValue(JsString(self.error_code()))),
        )

    def values(self) raises -> List[String]:
        self._require_success()
        var count = external_call["tsonic_node_dns_request_count", c_size_t](self._owner[].handle.value())
        var values = List[String](capacity=Int(count))
        for index in range(Int(count)):
            var value = external_call["tsonic_node_dns_request_value", OptionalPointer[UInt8, ImmUntrackedOrigin]](self._owner[].handle.value(), c_size_t(index))
            if not value:
                raise Error("DNS result lost an exact address entry")
            values.append(String(unsafe_from_utf8_ptr=value.value()))
        return values^

    def lookup_address(self) raises -> LookupAddress:
        var values = self.values()
        var family = external_call["tsonic_node_dns_request_family", c_int](self._owner[].handle.value())
        if len(values) != 1 or (family != 4 and family != 6):
            raise Error("OS lookup returned an invalid address/family result")
        return LookupAddress(values[0], family)

    def _require_success(self) raises:
        if not self.ready():
            raise Error("DNS result is not complete")
        if self.failed():
            raise Error(self.error_code() + ": " + self.error_message())


def poll_native_lookup() -> Bool:
    return external_call["tsonic_node_dns_lookup_poll", c_int]() != 0
