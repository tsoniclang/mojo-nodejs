from std.testing import assert_equal, assert_false, assert_true
from tsonic_runtime import create_raising_task
from tsonic_node.filesystem import (
    RmOptions,
    exists,
    lstat,
    make_directory_default,
    make_temp_directory,
    read_text_file,
    remove_directory,
    remove_path,
    symbolic_link,
    write_text_file,
)
from tsonic_node.filesystem.promises import (
    remove_directory as remove_directory_async,
)


def rejects(path: String) raises:
    var rejected = False
    try:
        remove_directory(path)
    except:
        rejected = True
    assert_true(rejected)


def main() raises:
    var root = make_temp_directory(".temp/directory-removal-")
    try:
        var empty = root + "/empty"
        make_directory_default(empty)
        remove_directory(empty)
        assert_false(exists(empty))
        rejects(empty)

        var file = root + "/file"
        write_text_file(file, "unchanged")
        rejects(file)
        assert_equal(read_text_file(file), "unchanged")

        var directory = root + "/occupied"
        make_directory_default(directory)
        write_text_file(directory + "/child", "retained")
        rejects(directory)
        assert_equal(read_text_file(directory + "/child"), "retained")

        var link = root + "/link"
        symbolic_link("occupied", link)
        rejects(link)
        assert_true(lstat(link).is_symbolic_link())
        assert_equal(read_text_file(directory + "/child"), "retained")

        var unicode = root + "/😀"
        make_directory_default(unicode)
        rejects(unicode + "\0ignored")
        assert_true(exists(unicode))
        var completion = create_raising_task(remove_directory_async(unicode))
        completion^.wait()
        assert_false(exists(unicode))

        var failure = create_raising_task(remove_directory_async(directory))
        var rejected = False
        try:
            failure^.wait()
        except:
            rejected = True
        assert_true(rejected)
        assert_equal(read_text_file(directory + "/child"), "retained")
    finally:
        remove_path(root, RmOptions(recursive=True))
