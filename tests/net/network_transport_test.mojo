from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.buffer import Buffer
from tsonic_node.internal.network_endpoint import monotonic_milliseconds
from tsonic_node.net import (
    ConnectionOptions,
    ServerOptions,
    Socket,
    create_connection_options,
    create_server_callback,
    create_server_options_callback,
    is_ip,
    is_ipv4,
    is_ipv6,
    poll_net,
    has_active_net,
)


@fieldwise_init
struct Accepted:
    var sockets: Location[List[Socket]]
    var throw_first: Location[Bool]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[Socket]
    ) raises:
        var environment = context.unsafe_bitcast[Accepted]()
        var sockets = environment[].sockets.read()
        sockets.append(arguments[0])
        environment[].sockets.write(sockets^)
        if environment[].throw_first.read():
            environment[].throw_first.write(False)
            raise Error("deliberate connection callback failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Accepted](context)


def on_connection(
    sockets: Location[List[Socket]], fail: Bool = False
) -> RaisingCallable[Tuple[Socket], NoneType]:
    var environment = allocate_callable_environment(
        Accepted(sockets, Location(fail)), Accepted.destroy
    )
    return RaisingCallable[Tuple[Socket], NoneType](
        environment, Accepted.invoke
    )


def poll_until_count(sockets: Location[List[Socket]], expected: Int) raises:
    var deadline = monotonic_milliseconds() + 5000
    while (
        len(sockets.read()) < expected and monotonic_milliseconds() < deadline
    ):
        _ = poll_net()
        sleep(0.001)
    assert_equal(len(sockets.read()), expected)


def exchange() raises:
    var accepted = Location(List[Socket]())
    var server = create_server_options_callback(
        ServerOptions(True, True), on_connection(accepted)
    )
    _ = server.listen_port_host(0, "127.0.0.1")
    assert_true(server.listening())
    var address = server.address().value()
    assert_true(address.port > 0)
    assert_equal(address.family, "IPv4")
    var client = create_connection_options(
        ConnectionOptions(address.port, "127.0.0.1", True)
    )
    assert_true(client.pending())
    assert_false(Bool(client.read()))
    var payload = Buffer.allocate(3 * 1024 * 1024, 179)
    assert_false(client.write_buffer(payload))
    _ = client.end()
    poll_until_count(accepted, 1)
    var peer = accepted.read()[0]
    assert_true(peer.is_paused())
    _ = peer.set_no_delay()
    var received = 0
    var deadline = monotonic_milliseconds() + 15000
    while received < len(payload) and monotonic_milliseconds() < deadline:
        _ = poll_net()
        var chunk = peer.read()
        if chunk:
            for byte in chunk.value().copy_bytes():
                assert_equal(byte, Byte(179))
            received += len(chunk.value())
        else:
            sleep(0.001)
    assert_equal(received, len(payload))
    assert_equal(client.bytes_written(), Float64(len(payload)))
    assert_equal(peer.bytes_read(), Float64(received))
    assert_false(client.pending())
    assert_false(peer.destroyed())
    _ = peer.end_string("reply after half close")
    var reply = String()
    deadline = monotonic_milliseconds() + 5000
    while (
        reply != "reply after half close"
        and monotonic_milliseconds() < deadline
    ):
        _ = poll_net()
        var chunk = client.read()
        if chunk:
            reply += chunk.value().to_string()
        else:
            sleep(0.001)
    assert_equal(reply, "reply after half close")
    _ = client.destroy()
    _ = peer.destroy()
    _ = server.close()
    _ = poll_net()
    assert_false(server.listening())
    assert_false(has_active_net())
    _ = server.listen_port_host(0, "127.0.0.1")
    assert_true(server.listening())
    _ = server.close()
    _ = poll_net()


def retained_connections() raises:
    var accepted = Location(List[Socket]())
    var server = create_server_callback(on_connection(accepted, True))
    _ = server.listen_port_host(0, "127.0.0.1")
    var port = server.address().value().port
    var first = create_connection_options(ConnectionOptions(port, "127.0.0.1"))
    var second = create_connection_options(ConnectionOptions(port, "127.0.0.1"))
    var rejected = False
    var deadline = monotonic_milliseconds() + 5000
    while not rejected and monotonic_milliseconds() < deadline:
        try:
            _ = poll_net()
        except error:
            assert_true(
                String(error).find("deliberate connection callback failure")
                >= 0
            )
            rejected = True
        sleep(0.001)
    assert_true(rejected)
    poll_until_count(accepted, 2)
    assert_false(first.destroyed())
    assert_false(second.destroyed())
    _ = first.destroy()
    _ = second.destroy()
    for socket in accepted.read():
        var retained_socket = socket
        _ = retained_socket.destroy()
    _ = server.close()
    _ = poll_net()
    assert_false(has_active_net())


def invalid_construction() raises:
    var timeouts = List[Float64](capacity=3)
    timeouts.append(-1)
    timeouts.append(Float64(FloatLiteral.nan))
    timeouts.append(Float64(FloatLiteral.infinity))
    for timeout in timeouts:
        var rejected = False
        try:
            _ = create_connection_options(
                ConnectionOptions(80, "localhost", timeout=timeout)
            )
        except:
            rejected = True
        assert_true(rejected)
        assert_false(has_active_net())


def main() raises:
    assert_equal(is_ip("127.0.0.1"), 4.0)
    assert_true(is_ipv4("127.0.0.1"))
    assert_true(is_ipv6("::1"))
    assert_equal(is_ip("127.0.0.1\0tail"), 0.0)
    invalid_construction()
    exchange()
    retained_connections()
