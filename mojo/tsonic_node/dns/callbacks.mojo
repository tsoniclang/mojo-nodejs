from std.collections import List
from std.utils import Variant
from tsonic_js import JsValue, js_value_from_null
from tsonic_runtime import GlobalCell
from ..internal.callback_queue import CallbackQueue
from .model import (
    LookupAddress,
    LookupCallback,
    AddressListCallback,
    LookupAllCallback,
    LookupAnyCallback,
    LookupCallbackResult,
)
from .native import DnsRequest, poll_native_lookup
from .options import LookupOptions, family_options


comptime DnsCallback = Variant[
    LookupCallback, AddressListCallback, LookupAllCallback, LookupAnyCallback
]
comptime REQUEST_LIMIT = 16384


@fieldwise_init
struct PendingRequest(ImplicitlyCopyable):
    var request: DnsRequest
    var callback: DnsCallback
    var all: Bool


def _initial_requests() -> List[PendingRequest]:
    return List[PendingRequest]()


def _initial_callbacks() -> CallbackQueue:
    return CallbackQueue(REQUEST_LIMIT)


comptime _requests = GlobalCell["tsonic.node.dns.requests", _initial_requests]()
comptime _callbacks = GlobalCell[
    "tsonic.node.dns.callbacks", _initial_callbacks
]()


def _enqueue(
    input: String,
    kind: Int32,
    callback: DnsCallback,
    options: LookupOptions = LookupOptions(),
) raises:
    if (
        len(_requests.get()[]) + _callbacks.get()[].pending_count()
        >= REQUEST_LIMIT
    ):
        raise Error("Pending DNS requests exceed the finite runtime limit")
    _requests.get()[].append(
        PendingRequest(
            DnsRequest(input, kind, options), callback, options.selected_all()
        )
    )


def lookup_callback(hostname: String, callback: LookupCallback) raises:
    _enqueue(hostname, 0, DnsCallback(callback))


def lookup_family_callback(
    hostname: String, family: Float64, callback: LookupCallback
) raises:
    _enqueue(hostname, 0, DnsCallback(callback), family_options(family))


def lookup_one_callback(
    hostname: String, options: LookupOptions, callback: LookupCallback
) raises:
    if options.selected_all():
        raise Error(
            "The selected DNS single-address callback requires all=false"
        )
    _enqueue(hostname, 0, DnsCallback(callback), options)


def lookup_all_callback(
    hostname: String, options: LookupOptions, callback: LookupAllCallback
) raises:
    if not options.selected_all():
        raise Error("The selected DNS address-list callback requires all=true")
    _enqueue(hostname, 0, DnsCallback(callback), options)


def lookup_any_callback(
    hostname: String, options: LookupOptions, callback: LookupAnyCallback
) raises:
    _enqueue(hostname, 0, DnsCallback(callback), options)


def resolve4_callback(hostname: String, callback: AddressListCallback) raises:
    _enqueue(hostname, 4, DnsCallback(callback))


def resolve6_callback(hostname: String, callback: AddressListCallback) raises:
    _enqueue(hostname, 6, DnsCallback(callback))


def reverse_callback(address: String, callback: AddressListCallback) raises:
    _enqueue(address, -1, DnsCallback(callback))


def has_pending_dns() -> Bool:
    return len(_requests.get()[]) != 0 or _callbacks.get()[].has_pending()


def _publish(pending: PendingRequest) raises:
    var failure = (
        pending.request.error_value() if pending.request.failed() else js_value_from_null()
    )
    if pending.callback.isa[LookupCallback]():
        var address = Optional[String]()
        var family = Optional[Float64]()
        if not pending.request.failed():
            var result = pending.request.lookup_address()
            family = result.family_value()
            address = result.address_value()
        _callbacks.get()[].defer(
            pending.callback.unsafe_get[LookupCallback](),
            (failure, address^, family),
        )
    elif pending.callback.isa[AddressListCallback]():
        var values = Optional[List[String]]()
        if not pending.request.failed():
            values = pending.request.values()
        _callbacks.get()[].defer(
            pending.callback.unsafe_get[AddressListCallback](),
            (failure, values^),
        )
    elif pending.callback.isa[LookupAllCallback]():
        var addresses = Optional[List[LookupAddress]]()
        if not pending.request.failed():
            addresses = pending.request.lookup_addresses()
        _callbacks.get()[].defer(
            pending.callback.unsafe_get[LookupAllCallback](),
            (failure, addresses^),
        )
    else:
        var address = Optional[LookupCallbackResult]()
        var family = Optional[Float64]()
        if not pending.request.failed():
            if pending.all:
                address = LookupCallbackResult(
                    pending.request.lookup_addresses()
                )
            else:
                var result = pending.request.lookup_address()
                address = LookupCallbackResult(result.address_value())
                family = result.family_value()
        _callbacks.get()[].defer(
            pending.callback.unsafe_get[LookupAnyCallback](),
            (failure, address^, family),
        )


def poll_dns() raises -> Bool:
    var worked = poll_native_lookup()
    var pending = List[PendingRequest]()
    swap(_requests.get()[], pending)
    for index in range(len(pending)):
        if not pending[index].request.ready():
            _requests.get()[].append(pending[index])
            continue
        try:
            _publish(pending[index])
            worked = True
        except error:
            for remaining in range(index, len(pending)):
                _requests.get()[].append(pending[remaining])
            raise error
    return _callbacks.get()[].poll() or worked
