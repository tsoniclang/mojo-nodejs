from std.testing import assert_equal, assert_false, assert_true
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.event_loop import run_event_loop
from tsonic_node.timers import (
    clear_interval,
    poll_timers,
    set_interval,
    set_timeout,
)


@fieldwise_init
struct TimerEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[],
    ) raises -> None:
        var environment = context.unsafe_bitcast[TimerEnvironment]()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[TimerEnvironment](context)


def callback(count: Location[Int]) -> RaisingCallable[Tuple[], NoneType]:
    var owner = allocate_callable_environment(
        TimerEnvironment(count), TimerEnvironment.destroy
    )
    return RaisingCallable[Tuple[], NoneType](owner, TimerEnvironment.invoke)


def main() raises:
    var count = Location(0)
    var timeout = set_timeout(callback(count), Int32(0))
    assert_true(timeout.has_ref())
    run_event_loop()
    assert_equal(count.read(), 1)
    assert_false(timeout.has_ref())

    var interval = set_interval(callback(count), Int32(1))
    sleep(0.003)
    assert_true(poll_timers())
    assert_equal(count.read(), 2)
    clear_interval(interval)
    assert_false(interval.has_ref())
