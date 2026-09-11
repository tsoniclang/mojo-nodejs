from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_true, assert_false
from tsonic_runtime import (
    RaisingCallable,
    ErasedCallableContext,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.filesystem import (
    CopyOptions,
    RmOptions,
    copy_tree,
    make_directory,
    symbolic_link,
    read_link,
    lstat,
    stat,
    exists,
    chmod,
    write_text_file,
    read_text_file_encoded,
    remove_path,
)


@fieldwise_init
struct FilterState:
    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[String, String]
    ) raises -> Bool:
        _ = context
        return not arguments[0].endswith("skip")


def check_rejected(
    source: String, destination: String, options: CopyOptions
) raises:
    var rejected = False
    try:
        copy_tree(source, destination, options)
    except:
        rejected = True
    assert_true(rejected)


def main() raises:
    var root = mkdtemp(prefix="tsonic-copy-")
    try:
        var source = root + "/source"
        make_directory(source)
        make_directory(source + "/skip")
        write_text_file(source + "/kept", "original")
        write_text_file(source + "/skip/hidden", "hidden")
        chmod(source, 0o1751)
        chmod(source + "/kept", 0o640)
        var options = CopyOptions()
        options.recursive = True
        var environment = allocate_callable_environment(
            FilterState(), destroy_callable_environment[FilterState]
        )
        options.filter = RaisingCallable[Tuple[String, String], Bool](
            environment, FilterState.invoke
        )
        copy_tree(source, root + "/filtered", options)
        assert_equal(
            read_text_file_encoded(root + "/filtered/kept", "utf8"), "original"
        )
        assert_false(exists(root + "/filtered/skip"))
        assert_equal(stat(root + "/filtered").mode & 0o7777, 0o1751)
        assert_equal(stat(root + "/filtered/kept").mode & 0o7777, 0o640)
        check_rejected(source, source + "/child", options)
        check_rejected(source + "/kept", source + "/kept", options)
        check_rejected(source, root + "/without-recursion", CopyOptions())
        copy_tree(source + "/kept", root + "/file")
        write_text_file(root + "/file", "retained")
        options.force = False
        options.error_on_exist = False
        copy_tree(source + "/kept", root + "/file", options)
        assert_equal(read_text_file_encoded(root + "/file", "utf8"), "retained")
        options.error_on_exist = True
        check_rejected(source + "/kept", root + "/file", options)
        options.force = True
        copy_tree(source + "/kept", root + "/file", options)
        assert_equal(read_text_file_encoded(root + "/file", "utf8"), "original")
        symbolic_link("kept", source + "/link")
        options.verbatim_symlinks = True
        copy_tree(source + "/link", root + "/literal-link", options)
        assert_equal(read_link(root + "/literal-link"), "kept")
        options.verbatim_symlinks = False
        copy_tree(source + "/link", root + "/resolved-link", options)
        assert_equal(read_link(root + "/resolved-link"), source + "/kept")
        options.dereference = True
        copy_tree(source + "/link", root + "/dereferenced", options)
        assert_false(lstat(root + "/dereferenced").is_symbolic_link())
        assert_equal(
            read_text_file_encoded(root + "/dereferenced", "utf8"), "original"
        )
        options.preserve_timestamps = True
        chmod(source + "/kept", 0o400)
        copy_tree(source + "/kept", root + "/readonly", options)
        assert_equal(stat(root + "/readonly").mode & 0o777, 0o400)
        assert_equal(
            stat(root + "/readonly").mtime_ms, stat(source + "/kept").mtime_ms
        )
        symbolic_link(".", source + "/cycle")
        check_rejected(source, root + "/cycle-copy", options)
        remove_path(source + "/cycle", RmOptions())
        options.mode = 8.0
        check_rejected(source + "/kept", root + "/bad-mode", options)
    finally:
        remove_path(root, RmOptions(True, True))
