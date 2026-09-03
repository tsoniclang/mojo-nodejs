from std.collections import List
from std.ffi import c_int, external_call
from tsonic_js import JsValue, js_value_error, js_value_from_undefined
from tsonic_runtime import GlobalCell, RaisingCallable


alias LookupCallback = RaisingCallable[
    Tuple[JsValue, String, Float64], NoneType
]
alias AddressListCallback = RaisingCallable[
    Tuple[JsValue, List[String]], NoneType
]


@fieldwise_init
struct LookupAddress(Copyable):
    var address: String
    var family: Int32

    def address_value(self) -> String:
        return self.address

    def family_value(self) -> Float64:
        return Float64(self.family)


@fieldwise_init
struct _PendingLookup:
    var error: JsValue
    var address: String
    var family: Float64
    var callback: LookupCallback


@fieldwise_init
struct _PendingAddresses:
    var error: JsValue
    var addresses: List[String]
    var callback: AddressListCallback


def _initial_lookup_queue() -> List[_PendingLookup]:
    return List[_PendingLookup]()


def _initial_addresses_queue() -> List[_PendingAddresses]:
    return List[_PendingAddresses]()


comptime _pending_lookups = GlobalCell[
    "tsonic.node.dns.pending-lookups", _initial_lookup_queue
]()
comptime _pending_addresses = GlobalCell[
    "tsonic.node.dns.pending-addresses", _initial_addresses_queue
]()
comptime _pending_limit = 1 << 20


def lookup(hostname: String) raises -> LookupAddress:
    var family = Int32(0)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call[
        "tsonic_node_dns_lookup",
        OptionalPointer[UInt8, MutUntrackedOrigin],
    ](
        hostname.as_c_string_slice().ptr().as_unsafe_any_origin(),
        Pointer(to=family),
        Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "DNS lookup failed"))
    return LookupAddress(_take_text(result), family)


def resolve4(hostname: String) raises -> List[String]:
    return _resolve(hostname, 4)


def resolve6(hostname: String) raises -> List[String]:
    return _resolve(hostname, 6)


def reverse(address: String) raises -> List[String]:
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call[
        "tsonic_node_dns_reverse",
        OptionalPointer[UInt8, MutUntrackedOrigin],
    ](
        address.as_c_string_slice().ptr().as_unsafe_any_origin(),
        Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "Reverse DNS lookup failed"))
    var values = List[String]()
    values.append(_take_text(result))
    return values^


def lookup_callback(
    hostname: String, callback: LookupCallback
) raises:
    _require_capacity()
    try:
        var result = lookup(hostname)
        _pending_lookups.get()[].append(
            _PendingLookup(
                js_value_from_undefined(),
                result.address,
                Float64(result.family),
                callback,
            )
        )
    except error:
        _pending_lookups.get()[].append(
            _PendingLookup(
                js_value_error(String(error)),
                "",
                0,
                callback,
            )
        )


def resolve4_callback(
    hostname: String, callback: AddressListCallback
) raises:
    _enqueue_addresses(hostname, 4, callback)


def resolve6_callback(
    hostname: String, callback: AddressListCallback
) raises:
    _enqueue_addresses(hostname, 6, callback)


def reverse_callback(
    address: String, callback: AddressListCallback
) raises:
    _require_capacity()
    try:
        _pending_addresses.get()[].append(
            _PendingAddresses(
                js_value_from_undefined(), reverse(address), callback
            )
        )
    except error:
        _pending_addresses.get()[].append(
            _PendingAddresses(
                js_value_error(String(error)), List[String](), callback
            )
        )


async def lookup_async(hostname: String) raises -> LookupAddress:
    return lookup(hostname)


async def resolve4_async(hostname: String) raises -> List[String]:
    return resolve4(hostname)


async def resolve6_async(hostname: String) raises -> List[String]:
    return resolve6(hostname)


async def reverse_async(address: String) raises -> List[String]:
    return reverse(address)


def has_pending_dns() -> Bool:
    return (
        len(_pending_lookups.get()[]) != 0
        or len(_pending_addresses.get()[]) != 0
    )


def poll_dns() raises -> Bool:
    if not has_pending_dns():
        return False
    var lookups = _pending_lookups.get()[]^
    _pending_lookups.get()[] = List[_PendingLookup]()
    for pending in lookups^:
        pending.callback.call(
            (pending.error, pending.address, pending.family)
        )
    var addresses = _pending_addresses.get()[]^
    _pending_addresses.get()[] = List[_PendingAddresses]()
    for pending in addresses^:
        pending.callback.call((pending.error, pending.addresses^))
    return True


def _resolve(hostname: String, family: Int32) raises -> List[String]:
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var result = external_call[
        "tsonic_node_dns_resolve",
        OptionalPointer[UInt8, MutUntrackedOrigin],
    ](
        hostname.as_c_string_slice().ptr().as_unsafe_any_origin(),
        family,
        Pointer(to=error),
    )
    if not result:
        raise Error(_take_error(error, "DNS resolution failed"))
    var text = _take_text(result)
    var values = List[String]()
    for value in text.split("\n"):
        values.append(String(value))
    return values^


def _enqueue_addresses(
    hostname: String,
    family: Int32,
    callback: AddressListCallback,
) raises:
    _require_capacity()
    try:
        _pending_addresses.get()[].append(
            _PendingAddresses(
                js_value_from_undefined(),
                _resolve(hostname, family),
                callback,
            )
        )
    except error:
        _pending_addresses.get()[].append(
            _PendingAddresses(
                js_value_error(String(error)), List[String](), callback
            )
        )


def _require_capacity() raises:
    if (
        len(_pending_lookups.get()[])
        + len(_pending_addresses.get()[])
        >= _pending_limit
    ):
        raise Error("Pending DNS callbacks exceed the finite runtime limit")


def _take_text(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin]
) -> String:
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^


def _take_error(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin],
    fallback: String,
) -> String:
    return _take_text(pointer) if pointer else fallback
