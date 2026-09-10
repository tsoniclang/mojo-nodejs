from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node.buffer import Buffer
from tsonic_node.filesystem import (
    RmOptions,
    access,
    append_file,
    chmod,
    close_file,
    copy_file,
    fstat,
    lstat,
    open_file,
    read_file,
    read_into,
    read_link,
    remove_path,
    stat,
    symbolic_link,
    make_temp_directory,
    truncate_file,
    write_from,
    write_string,
)


def main() raises:
    var root = mkdtemp(prefix="mojo-fs-descriptors-")
    var path = root + "/data"
    try:
        var first_temp = make_temp_directory(root + "/temp-")
        var second_temp = make_temp_directory(root + "/temp-")
        assert_true(first_temp != second_temp)
        assert_equal(
            first_temp.byte_length(), (root + "/temp-XXXXXX").byte_length()
        )
        assert_true(stat(first_temp).is_directory())
        var missing_parent = False
        try:
            _ = make_temp_directory(root + "/absent/temp-")
        except:
            missing_parent = True
        assert_true(missing_parent)
        var descriptor = open_file(path, "wx+")
        try:
            assert_equal(write_string(descriptor, "abc😀"), 7)
            var value = Buffer.allocate(12, 45)
            var retained_alias = value
            assert_equal(read_into(descriptor, value, 2, 7, 0), 7)
            assert_equal(
                retained_alias.subarray(2, Float64(9)).to_string(), "abc😀"
            )
            assert_equal(retained_alias.get(0), 45)
            assert_equal(
                write_from(descriptor, Buffer.from_string("xyz"), 0, 3, 0), 3
            )
            var selected = fstat(descriptor)
            assert_equal(selected.size, 7)
            assert_true(selected.is_file())
            assert_false(selected.is_symbolic_link())
            assert_true(selected.mtime_ms > 0)
            assert_equal(selected.mtime().get_time(), selected.mtime_ms)
            var rejected = False
            try:
                _ = read_into(descriptor, value, 10, 3, 0)
            except:
                rejected = True
            assert_true(rejected)
            assert_equal(value.get(10), 45)
        finally:
            close_file(descriptor)
        append_file(path, Buffer.from_string("!"))
        assert_equal(read_file(path).to_string(), "xyz😀!")
        access(path)
        chmod(path, 0o600)
        truncate_file(path, 3)
        assert_equal(read_file(path).to_string(), "xyz")
        symbolic_link("data", root + "/alias")
        assert_equal(read_link(root + "/alias"), "data")
        assert_true(lstat(root + "/alias").is_symbolic_link())
        assert_false(stat(root + "/alias").is_symbolic_link())
        copy_file(path, root + "/copy", 1)
        assert_equal(read_file(root + "/copy").to_string(), "xyz")
        var rejected = False
        try:
            copy_file(path, root + "/copy", 1)
        except:
            rejected = True
        assert_true(rejected)
        var options = RmOptions(
            recursive=True, force=True, max_retries=2, retry_delay=1
        )
        remove_path(root + "/alias", options)
        assert_equal(read_file(path).to_string(), "xyz")
        remove_path(root + "/absent", options)
        rejected = False
        try:
            remove_path(root, RmOptions(force=True))
        except:
            rejected = True
        assert_true(rejected)
        rejected = False
        try:
            remove_path(root, RmOptions(recursive=True, max_retries=-1))
        except:
            rejected = True
        assert_true(rejected)
    finally:
        remove_path(root, RmOptions(recursive=True, force=True))
