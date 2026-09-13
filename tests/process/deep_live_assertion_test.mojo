from std.memory import ArcPointer
from std.testing import assert_equal, assert_false, assert_true
from tsonic_runtime import (
    Callable,
    RaisingCallable,
    WeakReferenceIdentity,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_js import JsString, JsValue, js_value_from_source_object
from tsonic_node.assertions.deep import deep_value_equal


@fieldwise_init
struct Source:
    var value: Float64
    var reads: Int
    var json_calls: Int


@fieldwise_init
struct View:
    var source: ArcPointer[Source]

    @staticmethod
    def length(_context: ErasedCallableContext, var _arguments: Tuple[]) -> Int:
        return 1

    @staticmethod
    def key(
        _context: ErasedCallableContext, var _arguments: Tuple[Int]
    ) -> JsString:
        return JsString("value")

    @staticmethod
    def value(
        context: ErasedCallableContext, var _arguments: Tuple[Int]
    ) -> JsValue:
        var source = context.unsafe_bitcast[Self]()[].source
        source[].reads += 1
        return JsValue(source[].value)

    @staticmethod
    def to_json(
        context: ErasedCallableContext, var _arguments: Tuple[String]
    ) raises -> JsValue:
        var source = context.unsafe_bitcast[Self]()[].source
        source[].json_calls += 1
        return JsValue(99.0)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def view(source: ArcPointer[Source], prototype_identity: String) -> JsValue:
    var context = allocate_callable_environment(View(source), View.destroy)
    return js_value_from_source_object(
        WeakReferenceIdentity(source),
        prototype_identity,
        Callable[Tuple[], Int](context, View.length),
        Callable[Tuple[Int], JsString](context, View.key),
        Callable[Tuple[Int], JsValue](context, View.value),
        RaisingCallable[Tuple[String], JsValue, Error](context, View.to_json),
    )


def main() raises:
    var left = ArcPointer(Source(1.0, 0, 0))
    var right = ArcPointer(Source(1.0, 0, 0))
    var first = view(left, "proof.Counter")
    var same = view(right, "proof.Counter")
    var other = view(right, "proof.OtherCounter")
    var plain = view(right, "")
    assert_true(deep_value_equal(first, same))
    assert_equal(left[].reads, 1)
    assert_equal(right[].reads, 1)
    assert_false(deep_value_equal(first, other))
    assert_false(deep_value_equal(first, plain))
    assert_equal(left[].reads, 1)
    assert_equal(right[].reads, 1)
    left[].value = 2.0
    assert_false(deep_value_equal(first, same))
    right[].value = 2.0
    assert_true(deep_value_equal(first, same))
    assert_equal(left[].json_calls, 0)
    assert_equal(right[].json_calls, 0)
