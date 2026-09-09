from std.collections import List
from std.ffi import c_int, external_call
from tsonic_js import JsValue, js_value_error, js_value_from_null
from tsonic_runtime import GlobalCell, RaisingCallable
from .internal.callback_queue import CallbackQueue


comptime LookupCallback = RaisingCallable[Tuple[JsValue, Optional[String], Optional[Float64]], NoneType]
comptime AddressListCallback = RaisingCallable[Tuple[JsValue, Optional[List[String]]], NoneType]


@fieldwise_init
struct LookupAddress(Copyable):
    var address: String
    var family: Int32

    def address_value(self) -> String:
        return self.address

    def family_value(self) -> Float64:
        return Float64(self.family)


def _initial_queue() -> CallbackQueue:
    return CallbackQueue(1 << 20)


comptime _pending = GlobalCell["tsonic.node.dns.pending", _initial_queue]()


def lookup(hostname: String) raises -> LookupAddress:
    _validate_input(hostname)
    var hostname_buffer = String(hostname)
    var family = Int32(0)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call["tsonic_node_dns_lookup", OptionalPointer[UInt8, MutUntrackedOrigin]](
        hostname_buffer.as_c_string_slice().ptr().as_unsafe_any_origin(), Pointer(to=family), Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "DNS lookup failed"))
    return LookupAddress(_take_text(result), family)


def resolve4(hostname: String) raises -> List[String]:
    return _resolve(hostname, 4)


def resolve6(hostname: String) raises -> List[String]:
    return _resolve(hostname, 6)


def reverse(address: String) raises -> List[String]:
    _validate_input(address)
    var address_buffer = String(address)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call["tsonic_node_dns_reverse", OptionalPointer[UInt8, MutUntrackedOrigin]](
        address_buffer.as_c_string_slice().ptr().as_unsafe_any_origin(), Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "Reverse DNS lookup failed"))
    var values = List[String]()
    values.append(_take_text(result))
    return values^


def lookup_callback(hostname: String, callback: LookupCallback) raises:
    _validate_input(hostname)
    _pending.get()[].require_capacity()
    var failure = js_value_from_null()
    var address = Optional[String]()
    var family = Optional[Float64]()
    try:
        var result = lookup(hostname)
        address = result.address^
        family = Float64(result.family)
    except error:
        failure = js_value_error(String(error))
    _pending.get()[].defer(callback, (failure, address^, family))


def resolve4_callback(hostname: String, callback: AddressListCallback) raises:
    _enqueue_addresses(hostname, 4, callback)


def resolve6_callback(hostname: String, callback: AddressListCallback) raises:
    _enqueue_addresses(hostname, 6, callback)


def reverse_callback(address: String, callback: AddressListCallback) raises:
    _enqueue_addresses(address, 0, callback)


async def lookup_async(hostname: String) raises -> LookupAddress:
    return lookup(hostname)


async def resolve4_async(hostname: String) raises -> List[String]:
    return resolve4(hostname)


async def resolve6_async(hostname: String) raises -> List[String]:
    return resolve6(hostname)


async def reverse_async(address: String) raises -> List[String]:
    return reverse(address)


def has_pending_dns() -> Bool:
    return _pending.get()[].has_pending()


def poll_dns() raises -> Bool:
    return _pending.get()[].poll()


def _resolve(hostname: String, family: Int32) raises -> List[String]:
    _validate_input(hostname)
    var hostname_buffer = String(hostname)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call["tsonic_node_dns_resolve", OptionalPointer[UInt8, MutUntrackedOrigin]](
        hostname_buffer.as_c_string_slice().ptr().as_unsafe_any_origin(), family, Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "DNS resolution failed"))
    var text = _take_text(result)
    var values = List[String]()
    for value in text.split("\n"):
        values.append(String(value))
    return values^


def _enqueue_addresses(value: String, family: Int32, callback: AddressListCallback) raises:
    _validate_input(value)
    _pending.get()[].require_capacity()
    var failure = js_value_from_null()
    var addresses = Optional[List[String]]()
    try:
        addresses = reverse(value) if family == 0 else _resolve(value, family)
    except error:
        failure = js_value_error(String(error))
    _pending.get()[].defer(callback, (failure, addresses^))


def _validate_input(value: String) raises:
    if value.find("\0") != -1:
        raise Error("DNS input cannot contain a null byte")


def _take_text(pointer: OptionalPointer[UInt8, MutUntrackedOrigin]) -> String:
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^


def _take_error(pointer: OptionalPointer[UInt8, MutUntrackedOrigin], default_message: String) -> String:
    return _take_text(pointer) if pointer else default_message
