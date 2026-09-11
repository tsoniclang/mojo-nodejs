from std.testing import assert_equal
from tsonic_node.url import resolve, parse_legacy, format_url


def main() raises:
    assert_equal(
        resolve("http://example.test/a/b", "../c"), "http://example.test/c"
    )
    assert_equal(resolve("/a/b/c", "../../d"), "/d")
    assert_equal(resolve("a/b", "../../../c"), "../../c")
    assert_equal(
        resolve("http://a/b/c?query#old", "?next"), "http://a/b/c?next"
    )
    assert_equal(
        resolve("http://a/b/c?query#old", "#next"), "http://a/b/c?query#next"
    )
    assert_equal(resolve("http://a/b/c?query#old", ""), "http://a/b/c?query")
    assert_equal(resolve("http://a/b", "//other.test"), "http://other.test/")
    assert_equal(
        resolve("http://a/b", "https:other.test/path"),
        "https://other.test/path",
    )
    assert_equal(resolve("http://a/b", "."), "http://a/")
    assert_equal(resolve("http://a/b", ".."), "http://a/")
    assert_equal(
        resolve("mailto:local1@domain1", "local2@domain2"),
        "mailto:local2@domain2",
    )
    assert_equal(
        resolve("mailto:local1@domain1", "?subject=hello"),
        "mailto:local1@domain1?subject=hello",
    )
    assert_equal(
        resolve("http://user:pass@a/b", "//other@B/c"), "http://other@b/c"
    )
    assert_equal(
        resolve("http://a/b", "..\\hello world?q=\\"),
        "http://a/hello%20world?q=%5C",
    )
    assert_equal(resolve("http://a/b", "../😀/c"), "http://a/😀/c")
    assert_equal(resolve("file:///a/b", "../../c"), "file:///c")
    assert_equal(
        resolve("http://a/b", "http://[::1]:8080/x"), "http://[::1]:8080/x"
    )
    assert_equal(
        format_url(parse_legacy("http://user%3Apass@EXAMPLE.test:80/a")),
        "http://user:pass@example.test:80/a",
    )
