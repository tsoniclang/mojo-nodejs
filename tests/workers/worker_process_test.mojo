from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from std.time import sleep
from tsonic_js import JsString, JsValue
from tsonic_runtime import ErasedCallableContext, Location, RaisingCallable, allocate_callable_environment, destroy_callable_environment
from tsonic_node.worker_threads import WorkerOptions, worker_new, worker_data, parent_port, is_main_thread, thread_id, set_environment_data, get_environment_data, poll_worker_threads, has_active_worker_threads, source_module_entry, source_module_complete
from tsonic_node.internal.network_endpoint import monotonic_milliseconds


@fieldwise_init
struct CountMessage:
    var count: Location[Int]
    var code: Location[Float64]
    var exit: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[JsValue]) raises:
        var environment = context.unsafe_bitcast[CountMessage]()
        if environment[].exit:
            environment[].code.write(arguments[0].number_value())
        else:
            assert_equal(arguments[0].number_value(), 42.0)
            environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[CountMessage](context)


def listener(count: Location[Int], code: Location[Float64], exit: Bool = False) -> RaisingCallable[Tuple[JsValue], NoneType]:
    var environment = allocate_callable_environment(CountMessage(count, code, exit), CountMessage.destroy)
    return RaisingCallable[Tuple[JsValue], NoneType](environment, CountMessage.invoke)


def main() raises:
    var entry = source_module_entry()
    if entry:
        assert_equal(entry.value(), "worker-fixture")
        assert_false(is_main_thread())
        assert_true(thread_id() > 0)
        assert_equal(worker_data().number_value(), 42.0)
        assert_equal(get_environment_data(JsValue(JsString("mode"))).string_value(), JsString("fixture"))
        var port = parent_port().value()
        port.post_message(worker_data())
        port.close()
        source_module_complete(True, "")
        return
    assert_true(is_main_thread())
    set_environment_data(JsValue(JsString("mode")), JsValue(JsString("fixture")))
    var worker = worker_new("worker-fixture", WorkerOptions(worker_data=JsValue(42.0)))
    var count = Location(0)
    var code = Location(-1.0)
    _ = worker.on_callable1(JsValue(JsString("message")), listener(count, code))
    _ = worker.on_callable1(JsValue(JsString("exit")), listener(count, code, True))
    var deadline = monotonic_milliseconds() + 30000
    while has_active_worker_threads():
        _ = poll_worker_threads()
        assert_true(monotonic_milliseconds() < deadline)
        sleep(0.001)
    assert_equal(count.read(), 1)
    assert_equal(code.read(), 0.0)
    assert_equal(worker.thread_id(), -1.0)
