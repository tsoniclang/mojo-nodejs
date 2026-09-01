from std.testing import assert_equal, assert_false, assert_true
from std.tempfile import mkdtemp
from tsonic_node import (
    Buffer,
    MkdirOptions,
    ReaddirOptions,
    RmOptions,
    copy_file,
    exists,
    lstat,
    make_directory,
    read_directory,
    read_file,
    read_text_file,
    read_text_file_encoded,
    real_path,
    remove_path,
    rename_path,
    stat,
    symbolic_link,
    write_file,
    write_text_file,
)


def main() raises:
    var root = mkdtemp(prefix="tsonic-node-")
    var nested = root + "/a/b"
    make_directory(nested, MkdirOptions(recursive=True))
    assert_true(stat(nested).is_directory())

    var text_path = nested + "/message.txt"
    write_text_file(text_path, "hello")
    assert_equal(read_text_file(text_path), "hello")
    assert_equal(read_text_file_encoded(text_path, "utf8"), "hello")
    assert_true(stat(text_path).is_file())
    assert_equal(stat(text_path).size, 5)

    var binary_path = nested + "/data.bin"
    write_file(binary_path, Buffer.from_string("data"))
    assert_equal(read_file(binary_path).to_string(), "data")

    var copied_path = nested + "/copied.bin"
    copy_file(binary_path, copied_path)
    assert_equal(read_file(copied_path).to_string(), "data")

    var renamed_path = nested + "/renamed.bin"
    rename_path(copied_path, renamed_path)
    assert_false(exists(copied_path))
    assert_true(exists(renamed_path))

    var link_path = nested + "/message-link"
    symbolic_link(text_path, link_path)
    assert_true(lstat(link_path).is_symbolic_link())
    assert_equal(real_path(link_path), real_path(text_path))

    var entries = read_directory(nested, ReaddirOptions())
    assert_equal(len(entries), 4)

    remove_path(root, RmOptions(recursive=True))
    assert_false(exists(root))
