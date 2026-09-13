from std.testing import assert_true, assert_equal
from tsonic_node.zlib import create_gzip, gunzip_sync
from tsonic_node.zlib.duplex import as_duplex


def main() raises:
    var stream = create_gzip()
    var first = as_duplex(stream)
    var second = as_duplex(stream)
    assert_true(first.same(second))
    assert_true(first.write_string("first"))
    _ = second.end_string("second")
    assert_true(stream.closed())
    var bytes = first.read().value()
    assert_equal(gunzip_sync(bytes).to_string(), "firstsecond")
    assert_true(second.end().same(first))
