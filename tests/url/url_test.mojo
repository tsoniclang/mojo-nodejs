from std.testing import assert_equal, assert_false, assert_true
from tsonic_node.url import (
    LegacyUrl, URL, URLSearchParams, can_parse, domain_to_ascii, domain_to_unicode,
    file_url_to_path, file_url_to_path_buffer, format_url, path_to_file_url, url_parse,
)


def main() raises:
    var url = URL("../hello world?name=A+B&name=second#frag", "https://münich.example/a/b")
    assert_equal(url.hostname(), "xn--mnich-kva.example")
    assert_equal(url.pathname(), "/hello%20world")
    assert_equal(url.origin(), "https://xn--mnich-kva.example")
    var params = url.search_params()
    var retained_alias = url
    assert_equal(params.get("name").value(), "A B")
    assert_equal(len(params.get_all("name")), 2)
    params.append("nul", "a\0b")
    assert_true(retained_alias.href().find("nul=a%00b") >= 0)
    retained_alias.set_search("?next=one&next=two")
    assert_false(params.has("name"))
    assert_equal(params.get_all("next")[1], "two")
    params.set("next", "three")
    assert_equal(url.search(), "?next=three")
    params.append("next", "four")
    params.delete("next", "three")
    assert_equal(url.search(), "?next=four")
    assert_false(params.has("next", "three"))
    url.set_href("http://user:pass@localhost:80/path")
    assert_equal(params.size(), 0.0)
    assert_equal(url.port(), "")
    assert_equal(url.username(), "user")
    assert_equal(url.password(), "pass")
    url.set_port("invalid")
    assert_equal(url.port(), "")

    var standalone = URLSearchParams("z=%F0%9F%98%80&a=one&a=two&bad=%FF")
    standalone.sort()
    assert_equal(standalone.to_string(), "a=one&a=two&bad=%EF%BF%BD&z=%F0%9F%98%80")
    assert_equal(standalone.get("z").value(), "😀")
    assert_false(Bool(standalone.get("missing")))
    assert_true(can_parse("/path", "https://example.org"))
    assert_false(can_parse("not a URL"))
    assert_equal(domain_to_ascii("münich.example"), "xn--mnich-kva.example")
    assert_equal(domain_to_unicode("xn--mnich-kva.example"), "münich.example")
    assert_equal(domain_to_ascii("exa mple.org"), "")
    assert_equal(domain_to_ascii(""), "")
    assert_false(Bool(url_parse("http://[bad")))
    assert_true(Bool(url_parse("https://example.org")))
    var path = "/tmp/a b#?%\\😀"
    assert_equal(file_url_to_path(path_to_file_url(path)), path)
    assert_equal(file_url_to_path(path_to_file_url("/tmp/a\nb\tc\rd~[x]")), "/tmp/a\nb\tc\rd~[x]")
    assert_equal(path_to_file_url("/tmp/a/").pathname(), "/tmp/a/")
    assert_equal(file_url_to_path_buffer("file:///tmp/%FF").copy_bytes()[5], Byte(255))
    var rejected = False
    try:
        _ = file_url_to_path(URL("file:///tmp/a%2Fb"))
    except:
        rejected = True
    assert_true(rejected)
    var object = LegacyUrl()
    object.protocol = String("https")
    object.hostname = String("example.org")
    object.auth = String("a@b:c")
    object.pathname = String("a?#b")
    object.search = String("x=1#2")
    object.hash = String("section")
    assert_equal(format_url(object), "https://a%40b:c@example.org/a%3F%23b?x=1%232#section")
    rejected = False
    try:
        _ = file_url_to_path(URL("file://remote/tmp/a"))
    except:
        rejected = True
    assert_true(rejected)
