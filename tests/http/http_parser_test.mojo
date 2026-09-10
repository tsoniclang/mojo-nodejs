from std.collections import List
from std.testing import assert_equal, assert_true
from tsonic_node.http.parsing import RequestParser


def bytes(value: String) -> List[Byte]:
    var result = List[Byte]()
    for byte in value.as_bytes():
        result.append(byte)
    return result^


def rejects(value: String) raises:
    var parser = RequestParser()
    var input = bytes(value)
    var rejected = False
    try:
        _ = parser.feed(input, len(input))
    except:
        rejected = True
    assert_true(rejected)


def main() raises:
    var parser = RequestParser()
    var input = bytes(
        "POST /chunked HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding:"
        " chunked\r\n\r\n4;name=value\r\na\x00bc\r\n3\r\ndef\r\n0\r\nX-Trailer:"
        " yes\r\n\r\n"
    )
    var complete = False
    for index in range(len(input)):
        var fragment = List[Byte]()
        fragment.append(input[index])
        complete = parser.feed(fragment, 1)
        assert_equal(complete, index == len(input) - 1)
    var message = parser.message()
    assert_equal(message.method, "POST")
    assert_equal(message.url, "/chunked")
    var body = message.read_all_buffer().copy_bytes()
    assert_equal(len(body), 7)
    assert_equal(body[1], 0)
    assert_equal(body[6], Byte(102))
    assert_equal(len(message.read_all_buffer()), 0)
    rejects(
        "POST / HTTP/1.1\r\nContent-Length: 2\r\nContent-Length: 3\r\n\r\nabc"
    )
    rejects(
        "POST / HTTP/1.1\r\nContent-Length: 2\r\nTransfer-Encoding:"
        " chunked\r\n\r\n0\r\n\r\n"
    )
    rejects("POST / HTTP/1.1\r\nTransfer-Encoding: \r\n\r\n")
    rejects("GET / HTTP/1.1\r\nBad Header: value\r\n\r\n")
    rejects(
        "POST / HTTP/1.1\r\nTransfer-Encoding:"
        " chunked\r\n\r\nZ\r\nx\r\n0\r\n\r\n"
    )
    var oversized = String("GET /")
    for _ in range(65536):
        oversized += "a"
    rejects(oversized + " HTTP/1.1\r\n\r\n")
    var partial = RequestParser()
    var prefix = bytes("POST / HTTP/1.1\r\nContent-Length: 3\r\n\r\nab")
    assert_true(not partial.feed(prefix, len(prefix)))
    var premature = False
    try:
        _ = partial.message()
    except:
        premature = True
    assert_true(premature)
