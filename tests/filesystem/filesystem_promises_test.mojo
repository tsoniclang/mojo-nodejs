from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import (
    Buffer,
    MkdirOptions,
    RmOptions,
    exists,
    make_directory_async,
    read_directory_async,
    read_file_async,
    read_text_file_async,
    remove_path_async,
    rename_path_async,
    stat_async,
    write_file_async,
)
from tsonic_runtime import create_raising_task
from tsonic_node.filesystem.promises import append_text_file, real_path, symbolic_link, make_temp_directory


async def nested_read(path: String) raises -> String:
    return await create_raising_task(read_text_file_async(path, "utf8"))


def main() raises:
    var root = mkdtemp(prefix="tsonic-node-promises-")
    var nested = root + "/a/b"
    var mkdir_task = create_raising_task(
        make_directory_async(nested, MkdirOptions(recursive=True))
    )
    mkdir_task^.wait()
    var directory_task = create_raising_task(stat_async(nested))
    assert_true(directory_task^.wait().is_directory())

    var source = nested + "/value.txt"
    var write_task = create_raising_task(
        write_file_async(source, Buffer.from_string("value"))
    )
    write_task^.wait()
    var read_task = create_raising_task(read_file_async(source))
    assert_equal(read_task^.wait().to_string(), "value")
    var nested_task = create_raising_task(nested_read(source))
    assert_equal(nested_task^.wait(), "value")
    var directory_read_task = create_raising_task(read_directory_async(nested))
    assert_equal(len(directory_read_task^.wait()), 1)

    var destination = nested + "/next.txt"
    var rename_task = create_raising_task(
        rename_path_async(source, destination)
    )
    rename_task^.wait()
    var file_task = create_raising_task(stat_async(destination))
    assert_true(file_task^.wait().is_file())
    var append_task = create_raising_task(append_text_file(destination, "!"))
    append_task^.wait()
    var appended = create_raising_task(read_text_file_async(destination, "utf8"))
    assert_equal(appended^.wait(), "value!")
    var link_task = create_raising_task(symbolic_link(destination, root + "/alias"))
    link_task^.wait()
    var real_task = create_raising_task(real_path(root + "/alias"))
    assert_equal(real_task^.wait(), destination)
    var temp_task = create_raising_task(make_temp_directory(root + "/temp-"))
    assert_true(exists(temp_task^.wait()))
    var remove_task = create_raising_task(
        remove_path_async(root, RmOptions(recursive=True))
    )
    remove_task^.wait()
    assert_false(exists(root))
