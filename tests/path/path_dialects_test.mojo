from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from tsonic_node.path import posix_value, win32_value
from tsonic_node.path.win32 import resolve_with_cwd


def strings(first: String, second: String = "") -> List[String]:
    var result = List[String]()
    result.append(first)
    result.append(second)
    return result^


def main() raises:
    var windows = win32_value()
    var posix = posix_value()
    assert_equal(windows.separator(), "\\")
    assert_equal(windows.delimiter(), ";")
    assert_equal(posix.separator(), "/")
    assert_equal(posix.delimiter(), ":")
    assert_true(windows.is_absolute("C:\\work"))
    assert_false(windows.is_absolute("C:work"))
    assert_true(windows.is_absolute("\\\\host\\share"))
    assert_false(posix.is_absolute("C:\\work"))
    assert_equal(windows.normalize("C:\\work\\..\\assets\\"), "C:\\assets\\")
    assert_equal(windows.normalize("C:work\\..\\assets"), "C:assets")
    assert_equal(
        windows.normalize("\\\\host\\share\\..\\asset"),
        "\\\\host\\share\\asset",
    )
    assert_equal(windows.normalize("\\\\host\\share"), "\\\\host\\share\\")
    assert_equal(windows.normalize("one/../C:/file"), ".\\C:\\file")
    assert_equal(windows.normalize(":"), ":")
    assert_equal(windows.normalize("COM1:"), ".\\COM1:.")
    assert_equal(windows.join(strings("\\\\", "host\\share")), "\\host\\share")
    assert_equal(
        windows.join(strings("\\\\host", "share")), "\\\\host\\share\\"
    )
    var parsed = windows.parse("C:\\work\\article.md")
    assert_equal(parsed.root, "C:\\")
    assert_equal(parsed.directory, "C:\\work")
    assert_equal(parsed.base, "article.md")
    assert_equal(parsed.name, "article")
    assert_equal(parsed.extension, ".md")
    assert_equal(windows.format_path(parsed), "C:\\work\\article.md")
    assert_equal(windows.parse("\\\\host\\share").base, "")
    assert_equal(windows.basename("\\\\host\\share"), "share")
    assert_equal(windows.dirname("C:article.md"), "C:")
    assert_equal(
        windows.relative("C:\\work\\posts", "c:\\WORK\\Assets"), "..\\Assets"
    )
    assert_equal(windows.relative("C:\\one", "D:\\two"), "D:\\two")
    assert_equal(
        resolve_with_cwd(strings("C:article.md"), "D:\\work", "C:\\content"),
        "C:\\content\\article.md",
    )
    assert_equal(
        resolve_with_cwd(strings("C:article.md"), "D:\\work"), "C:\\article.md"
    )
    assert_equal(
        windows.to_namespaced_path("C:\\work\\article.md"),
        "\\\\?\\C:\\work\\article.md",
    )
    assert_equal(
        windows.to_namespaced_path("\\\\host\\share\\article.md"),
        "\\\\?\\UNC\\host\\share\\article.md",
    )
    assert_equal(
        posix.to_namespaced_path("C:\\work\\article.md"), "C:\\work\\article.md"
    )
    assert_equal(windows.posix().join(strings("/one", "two")), "/one/two")
    assert_equal(posix.win32().join(strings("C:\\one", "two")), "C:\\one\\two")
