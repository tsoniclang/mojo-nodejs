from std.collections import List
from std.time import sleep
from std.testing import assert_equal, assert_true, assert_false
from tsonic_js import JsValue
from tsonic_runtime import (
    Location,
    ErasedCallableContext,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.dns import (
    LookupCallback,
    AddressListCallback,
    lookup_callback,
    reverse_callback,
    poll_dns,
    has_pending_dns,
)
from tsonic_node.dns.native import DnsRequest, poll_native_lookup
from tsonic_node.dns.options import LookupOptions
from tsonic_node.dns.model import LookupAddress, LookupAllCallback
from tsonic_node.dns.callbacks import lookup_all_callback
from std.utils import Variant


@fieldwise_init
struct LookupCompletion:
    var count: Location[Int]
    var fail: Bool

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[JsValue, Optional[String], Optional[Float64]],
    ) raises:
        var completion = context.unsafe_bitcast[LookupCompletion]()
        assert_true(arguments[0].is_null())
        assert_equal(arguments[1].value(), "127.0.0.1")
        assert_equal(arguments[2].value(), 4.0)
        completion[].count.write(completion[].count.read() + 1)
        if completion[].fail:
            raise Error("deliberate DNS callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[LookupCompletion](context)


def completed(count: Location[Int], fail: Bool = False) -> LookupCallback:
    var environment = allocate_callable_environment(
        LookupCompletion(count, fail), LookupCompletion.destroy
    )
    return LookupCallback(environment, LookupCompletion.invoke)


@fieldwise_init
struct FailureCompletion:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[JsValue, Optional[List[String]]],
    ) raises:
        var completion = context.unsafe_bitcast[FailureCompletion]()
        assert_false(arguments[0].is_null())
        assert_false(arguments[1])
        completion[].count.write(completion[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[FailureCompletion](context)


@fieldwise_init
struct AllCompletion:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[JsValue, Optional[List[LookupAddress]]],
    ) raises:
        assert_true(arguments[0].is_null())
        ref addresses = arguments[1].value()
        assert_equal(len(addresses), 1)
        assert_equal(addresses[0].address, "127.0.0.1")
        assert_equal(addresses[0].family, 4)
        var count = context.unsafe_bitcast[AllCompletion]()[].count
        count.write(count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[AllCompletion](context)


def main() raises:
    var options = LookupOptions()
    options.family = Variant[Float64, String](String("IPv4"))
    options.all = True
    options.verbatim = False
    options.order = "ipv6first"
    assert_equal(options.selected_order(), 6)
    var all_count = Location(0)
    var all_environment = allocate_callable_environment(
        AllCompletion(all_count), AllCompletion.destroy
    )
    lookup_all_callback(
        "127.0.0.1",
        options,
        LookupAllCallback(all_environment, AllCompletion.invoke),
    )
    options.all = False
    options.family = Variant[Float64, String](String("not-a-family"))
    assert_equal(all_count.read(), 0)
    _ = poll_dns()
    assert_equal(all_count.read(), 1)
    var invalid = False
    try:
        _ = DnsRequest("localhost", 0, options)
    except:
        invalid = True
    assert_true(invalid)
    var input = String("127.0.0.1")
    var request = DnsRequest(input, 0)
    assert_equal(input, "127.0.0.1")
    input = "changed-after-request.invalid"
    for turn in range(10000):
        _ = poll_native_lookup()
        if request.ready():
            break
        sleep(0.001)
    assert_true(request.ready())
    assert_false(request.failed())
    assert_equal(request.lookup_address().address, "127.0.0.1")
    assert_equal(input, "changed-after-request.invalid")
    var count = Location(0)
    lookup_callback("127.0.0.1", completed(count, True))
    lookup_callback("127.0.0.1", completed(count))
    assert_equal(count.read(), 0)
    var failures = 0
    for turn in range(10000):
        try:
            _ = poll_dns()
        except error:
            assert_equal(String(error), "deliberate DNS callback failure")
            failures += 1
        if not has_pending_dns():
            break
        sleep(0.001)
    assert_equal(failures, 1)
    assert_equal(count.read(), 2)
    assert_false(has_pending_dns())
    var environment = allocate_callable_environment(
        FailureCompletion(count), FailureCompletion.destroy
    )
    reverse_callback(
        "not-an-IP-address",
        AddressListCallback(environment, FailureCompletion.invoke),
    )
    assert_true(poll_dns())
    assert_equal(count.read(), 3)
    var rejected = False
    try:
        lookup_callback("127.0.0.1\0.invalid", completed(count))
    except:
        rejected = True
    assert_true(rejected)
    assert_false(has_pending_dns())
