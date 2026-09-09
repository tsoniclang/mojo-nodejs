from std.collections import List
from std.testing import assert_equal, assert_true, assert_false
from tsonic_js import JsValue
from tsonic_runtime import Location, ErasedCallableContext, RaisingCallable, allocate_callable_environment, destroy_callable_environment
from tsonic_node.dns import LookupCallback, AddressListCallback, lookup, lookup_callback, reverse_callback, poll_dns, has_pending_dns


@fieldwise_init
struct LookupCompletion:
    var count: Location[Int]
    var fail: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[JsValue, Optional[String], Optional[Float64]]) raises:
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
    var environment = allocate_callable_environment(LookupCompletion(count, fail), LookupCompletion.destroy)
    return LookupCallback(environment, LookupCompletion.invoke)


@fieldwise_init
struct FailureCompletion:
    var count: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[JsValue, Optional[List[String]]]) raises:
        var completion = context.unsafe_bitcast[FailureCompletion]()
        assert_false(arguments[0].is_null())
        assert_false(arguments[1])
        completion[].count.write(completion[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[FailureCompletion](context)


def main() raises:
    var count = Location(0)
    lookup_callback("127.0.0.1", completed(count, True))
    lookup_callback("127.0.0.1", completed(count))
    assert_equal(count.read(), 0)
    var rejected = False
    try:
        _ = poll_dns()
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(count.read(), 1)
    assert_true(has_pending_dns())
    assert_true(poll_dns())
    assert_equal(count.read(), 2)
    assert_false(has_pending_dns())
    var environment = allocate_callable_environment(FailureCompletion(count), FailureCompletion.destroy)
    reverse_callback("not-an-IP-address", AddressListCallback(environment, FailureCompletion.invoke))
    assert_true(poll_dns())
    assert_equal(count.read(), 3)
    rejected = False
    try:
        _ = lookup("127.0.0.1\0.invalid")
    except:
        rejected = True
    assert_true(rejected)
