from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import (
    basename,
    dirname,
    extname,
    format_path,
    is_absolute,
    join,
    normalize,
    parse,
    relative,
)


def main() raises:
    assert_equal(normalize("/alpha//beta/../gamma/"), "/alpha/gamma/")
    assert_equal(normalize("alpha/./beta"), "alpha/beta")
    assert_equal(normalize(""), ".")
    assert_true(is_absolute("/alpha"))
    assert_false(is_absolute("alpha"))

    var parts = List[String]()
    parts.append("alpha")
    parts.append("beta")
    parts.append("..")
    parts.append("gamma")
    assert_equal(join(parts^), "alpha/gamma")

    assert_equal(dirname("/alpha/beta.txt"), "/alpha")
    assert_equal(basename("/alpha/beta.txt"), "beta.txt")
    assert_equal(basename("/alpha/beta.txt", ".txt"), "beta")
    assert_equal(extname("/alpha/beta.txt"), ".txt")
    assert_equal(extname("/alpha/.profile"), "")

    var parsed = parse("/alpha/beta.txt")
    assert_equal(parsed.root, "/")
    assert_equal(parsed.directory, "/alpha")
    assert_equal(parsed.base, "beta.txt")
    assert_equal(parsed.name, "beta")
    assert_equal(parsed.extension, ".txt")
    assert_equal(format_path(parsed), "/alpha/beta.txt")

    assert_equal(relative("/alpha/beta", "/alpha/gamma/item"), "../gamma/item")
