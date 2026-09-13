from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_true, assert_false
from tsonic_runtime import (
    ClosedRaisingCoroutine,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
    create_raising_task,
    make_async_callable,
    take_async_invocation,
    adapt_callable_result,
    widen_callable,
)
from tsonic_node.filesystem import (
    AsyncCopyOptions,
    RmOptions,
    make_directory,
    stat,
    exists,
    chmod,
    write_text_file,
    read_text_file_encoded,
    remove_path,
    promises,
)
from tsonic_node.filesystem.copy_options import CopyFilterResult


@fieldwise_init
struct FilterState:
    @staticmethod
    def selected_result(
        var future: ClosedRaisingCoroutine[Bool],
    ) -> CopyFilterResult:
        return CopyFilterResult(future^)

    @staticmethod
    def asynchronous(
        context: ErasedCallableContext,
    ) -> ClosedRaisingCoroutine[Bool]:
        return FilterState.decide(context)

    @staticmethod
    async def decide(context: ErasedCallableContext) raises -> Bool:
        var invocation = take_async_invocation[Tuple[String, String]](context)
        ref arguments = invocation[1]
        try:
            return not arguments[0].endswith("skip")
        finally:
            _ = invocation

    @staticmethod
    def throwing(
        context: ErasedCallableContext,
    ) -> ClosedRaisingCoroutine[Bool]:
        return FilterState.fail_child(context)

    @staticmethod
    async def fail_child(context: ErasedCallableContext) raises -> Bool:
        var invocation = take_async_invocation[Tuple[String, String]](context)
        ref arguments = invocation[1]
        try:
            if not arguments[0].endswith("source"):
                raise Error("copy filter rejected child")
            return True
        finally:
            _ = invocation


async def check_async(root: String) raises:
    var options = AsyncCopyOptions()
    options.recursive = True
    var environment = allocate_callable_environment(
        FilterState(), destroy_callable_environment[FilterState]
    )
    options.filter = widen_callable(
        adapt_callable_result(
            make_async_callable[Tuple[String, String], Bool](
                environment, FilterState.asynchronous
            ),
            FilterState.selected_result,
        )
    )
    await create_raising_task(
        promises.copy_tree(root + "/source", root + "/async", options)
    )
    assert_equal(
        read_text_file_encoded(root + "/async/kept", "utf8"), "original"
    )
    assert_false(exists(root + "/async/skip"))
    chmod(root + "/source", 0o751)
    options.filter = widen_callable(
        adapt_callable_result(
            make_async_callable[Tuple[String, String], Bool](
                environment, FilterState.throwing
            ),
            FilterState.selected_result,
        )
    )
    var rejected = False
    try:
        await create_raising_task(
            promises.copy_tree(
                root + "/source", root + "/async-failure", options
            )
        )
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(stat(root + "/async-failure").mode & 0o777, 0o751)


def main() raises:
    var root = mkdtemp(prefix="tsonic-copy-async-")
    try:
        make_directory(root + "/source")
        make_directory(root + "/source/skip")
        write_text_file(root + "/source/kept", "original")
        write_text_file(root + "/source/skip/hidden", "hidden")
        create_raising_task(check_async(root)).wait()
    finally:
        remove_path(root, RmOptions(True, True))
