from std.collections import List
from std.time import sleep
from .model import LookupAddress, LookupResult
from .native import DnsRequest, poll_native_lookup
from .options import LookupOptions, family_options


def _wait(request: DnsRequest):
    while not request.ready():
        _ = poll_native_lookup()
        if not request.ready():
            sleep(0.001)


async def lookup_async(hostname: String) raises -> LookupAddress:
    var request = DnsRequest(hostname, 0)
    _wait(request)
    return request.lookup_address()


async def lookup_family_async(hostname: String, family: Float64) raises -> LookupAddress:
    var request = DnsRequest(hostname, 0, family_options(family))
    _wait(request)
    return request.lookup_address()


async def lookup_one_async(hostname: String, options: LookupOptions) raises -> LookupAddress:
    if options.selected_all():
        raise Error("The selected DNS single-address result requires all=false")
    var request = DnsRequest(hostname, 0, options)
    _wait(request)
    return request.lookup_address()


async def lookup_all_async(hostname: String, options: LookupOptions) raises -> List[LookupAddress]:
    if not options.selected_all():
        raise Error("The selected DNS address-list result requires all=true")
    var request = DnsRequest(hostname, 0, options)
    _wait(request)
    return request.lookup_addresses()


async def lookup_any_async(hostname: String, options: LookupOptions) raises -> LookupResult:
    var request = DnsRequest(hostname, 0, options)
    _wait(request)
    if options.selected_all():
        return LookupResult(request.lookup_addresses())
    return LookupResult(request.lookup_address())


async def resolve4_async(hostname: String) raises -> List[String]:
    var request = DnsRequest(hostname, 4)
    _wait(request)
    return request.values()


async def resolve6_async(hostname: String) raises -> List[String]:
    var request = DnsRequest(hostname, 6)
    _wait(request)
    return request.values()


async def reverse_async(address: String) raises -> List[String]:
    var request = DnsRequest(address, -1)
    _wait(request)
    return request.values()
