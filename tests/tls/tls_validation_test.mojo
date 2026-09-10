from std.collections import List
from std.testing import assert_equal, assert_true
from tsonic_node.tls import ConnectionOptions, connect


def rejected(options: ConnectionOptions, message: String) raises:
    var failed = False
    try:
        var socket = connect(options)
        socket.destroy()
    except error:
        assert_equal(String(error), message)
        failed = True
    assert_true(failed)


def main() raises:
    rejected(
        ConnectionOptions(host=Optional("localhost\0.invalid")),
        "TLS host contains a null byte",
    )
    rejected(
        ConnectionOptions(servername=Optional("localhost\0.invalid")),
        "TLS host contains a null byte",
    )
    var authorities = List[String]()
    authorities.append("certificate\0trailing")
    rejected(
        ConnectionOptions(ca=Optional(authorities^)),
        "TLS authority contains a null byte",
    )
