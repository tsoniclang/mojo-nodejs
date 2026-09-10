from std.collections import List
from std.time import sleep
from .model import LookupAddress
from .native import DnsRequest, poll_native_lookup


def _wait(request: DnsRequest):
    while not request.ready():
        _ = poll_native_lookup()
        if not request.ready():
            sleep(0.001)


async def lookup_async(hostname: String) raises -> LookupAddress:
    var request = DnsRequest(hostname, 0)
    _wait(request)
    return request.lookup_address()


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
