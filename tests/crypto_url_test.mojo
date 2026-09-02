from std.testing import assert_equal, assert_false, assert_true
from tsonic_node import Buffer, create_hash, parse_legacy


def main() raises:
    assert_equal(
        create_hash("sha256").update_string("").digest("hex"),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )
    assert_equal(
        create_hash("sha256").update_string("abc").digest("hex"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    assert_equal(
        create_hash("sha1").update_string("abc").digest("hex"),
        "a9993e364706816aba3e25717850c26c9cd0d89d",
    )
    assert_equal(
        create_hash("md5").update_string("abc").digest("hex"),
        "900150983cd24fb0d6963f7d28e17f72",
    )
    assert_equal(
        create_hash("sha256")
        .update_buffer(Buffer.from_string("abc"))
        .digest("base64"),
        "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=",
    )
    assert_equal(
        create_hash("sha256")
        .update_string("a")
        .update_string("bc")
        .digest("hex"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )

    var absolute = parse_legacy("https://user@example.com:8443/a/b?q=one#part")
    assert_equal(absolute.protocol.value(), "https:")
    assert_true(absolute.slashes.value())
    assert_equal(absolute.auth.value(), "user")
    assert_equal(absolute.host.value(), "example.com:8443")
    assert_equal(absolute.hostname.value(), "example.com")
    assert_equal(absolute.port.value(), "8443")
    assert_equal(absolute.pathname.value(), "/a/b")
    assert_equal(absolute.search.value(), "?q=one")
    assert_equal(absolute.query.value(), "q=one")
    assert_equal(absolute.hash.value(), "#part")
    assert_equal(absolute.path.value(), "/a/b?q=one")

    var relative = parse_legacy("docs/page.html?draft=true")
    assert_false(Bool(relative.protocol))
    assert_false(Bool(relative.host))
    assert_equal(relative.pathname.value(), "docs/page.html")
    assert_equal(relative.query.value(), "draft=true")
