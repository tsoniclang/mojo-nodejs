from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext, Location, RaisingCallable,
    allocate_callable_environment, destroy_callable_environment,
)
from tsonic_node import RmOptions, remove_path, write_text_file
from tsonic_node.filesystem import Stats
from tsonic_node.filesystem.watch import (
    WatchOptions, poll_watchers, unwatch_file, watch, watch_file,
)


@fieldwise_init
struct ChangeEnvironment:
    var calls: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[String, Optional[String]]) raises:
        assert_true(arguments[0] == "change" or arguments[0] == "rename")
        var environment = context.unsafe_bitcast[ChangeEnvironment]()
        environment[].calls.write(environment[].calls.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[ChangeEnvironment](context)


@fieldwise_init
struct StatEnvironment:
    var calls: Location[Int]
    var size: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[Stats, Stats]):
        var environment = context.unsafe_bitcast[StatEnvironment]()
        environment[].calls.write(environment[].calls.read() + 1)
        environment[].size.write(arguments[0].size)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[StatEnvironment](context)


def wait_for(calls: Location[Int], minimum: Int) raises:
    for _ in range(500):
        _ = poll_watchers()
        if calls.read() >= minimum:
            return
        sleep(0.01)
    raise Error("Filesystem watch notification did not arrive")


def main() raises:
    var root = mkdtemp(prefix="tsonic-file-watch-")
    try:
        var path = root + "/😀.txt"
        write_text_file(path, "one")
        var calls = Location(0)
        var owner = allocate_callable_environment(ChangeEnvironment(calls), ChangeEnvironment.destroy)
        var change = RaisingCallable[Tuple[String, Optional[String]], NoneType](owner, ChangeEnvironment.invoke)
        var watcher = watch(path, change)
        var retained_alias = watcher
        assert_true(watcher.has_ref())
        _ = watcher.unref()
        assert_false(retained_alias.has_ref())
        _ = retained_alias.ref()
        assert_true(watcher.has_ref())
        write_text_file(path, "changed")
        wait_for(calls, 1)
        retained_alias.close()
        watcher.close()
        var before = calls.read()
        write_text_file(path, "after close")
        for _ in range(4):
            _ = poll_watchers()
        assert_equal(calls.read(), before)
        assert_false(watcher.has_ref())

        var stat_calls = Location(0)
        var size = Location(-1)
        var stat_owner = allocate_callable_environment(StatEnvironment(stat_calls, size), StatEnvironment.destroy)
        var listener = RaisingCallable[Tuple[Stats, Stats], NoneType](stat_owner, StatEnvironment.invoke)
        var options = WatchOptions()
        options.interval = 1.0
        var missing = root + "/created-later"
        var stat_watcher = watch_file(missing, options, listener)
        wait_for(stat_calls, 1)
        assert_equal(size.read(), 0)
        write_text_file(missing, "created")
        wait_for(stat_calls, 2)
        assert_equal(size.read(), 7)
        unwatch_file(missing)
        assert_false(stat_watcher.has_ref())
        _ = poll_watchers()
    finally:
        remove_path(root, RmOptions(recursive=True))
