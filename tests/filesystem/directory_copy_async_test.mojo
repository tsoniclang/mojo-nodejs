from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_true, assert_false
from tsonic_runtime import (
    RaisingCallable,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
    create_raising_task,
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
    def asynchronous(
        context: ErasedCallableContext, var arguments: Tuple[String, String]
    ) raises -> CopyFilterResult:
        _ = context
        return CopyFilterResult(FilterState.decide(arguments[0]))

    @staticmethod
    async def decide(path: String) raises -> Bool:
        return not path.endswith("skip")

    @staticmethod
    def throwing(
        context: ErasedCallableContext, var arguments: Tuple[String, String]
    ) raises -> CopyFilterResult:
        _ = context
        return CopyFilterResult(FilterState.fail_child(arguments[0]))

    @staticmethod
    async def fail_child(path: String) raises -> Bool:
        if not path.endswith("source"):
            raise Error("copy filter rejected child")
        return True


async def check_async(root: String) raises:
    var options = AsyncCopyOptions()
    options.recursive = True
    var environment = allocate_callable_environment(
        FilterState(), destroy_callable_environment[FilterState]
    )
    options.filter = RaisingCallable[Tuple[String, String], CopyFilterResult](
        environment, FilterState.asynchronous
    )
    await create_raising_task(
        promises.copy_tree(root + "/source", root + "/async", options)
    )
    assert_equal(
        read_text_file_encoded(root + "/async/kept", "utf8"), "original"
    )
    assert_false(exists(root + "/async/skip"))
    chmod(root + "/source", 0o751)
    options.filter = RaisingCallable[Tuple[String, String], CopyFilterResult](
        environment, FilterState.throwing
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
