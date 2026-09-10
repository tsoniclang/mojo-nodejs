from std.testing import assert_equal
from std.collections import List
from tsonic_node.path import win32


def main() raises:
    var names: List[String] = ["COM1:", "LPT¹:", "NUL:part"]
    for name in names:
        assert_equal(
            win32.resolve_with_cwd([name], "C:\\work"),
            "C:\\work\\" + name,
        )
    assert_equal(win32.normalize("COM1:"), ".\\COM1:.")
    assert_equal(win32.resolve_with_cwd(["D:part"], "C:\\work"), "D:\\part")
    assert_equal(
        win32.resolve_with_cwd(["D:part"], "C:\\work", "D:\\saved"),
        "D:\\saved\\part",
    )
    assert_equal(
        win32.resolve_with_cwd(["\\\\?\\C:\\work\\..\\file"], "C:\\base"),
        "\\\\?\\C:\\file",
    )
    assert_equal(win32.relative("/a", "\\root"), "\\root")
    assert_equal(win32.relative("\\one\\a", "\\two\\b"), "\\two\\b")
    assert_equal(win32.relative("\\same\\a", "\\same\\b"), "..\\b")
    assert_equal(win32.relative("C:\\one", "C:\\two"), "..\\two")
