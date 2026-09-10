from std.collections import List
from std.testing import assert_equal, assert_false, assert_true
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    TsError,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.filesystem import read_text_file
from tsonic_node.internal.network_endpoint import (
    NetworkEndpoint,
    monotonic_milliseconds,
)
from tsonic_node.tls import (
    ConnectionOptions,
    TlsOptions,
    TLSSocket,
    connect,
    create_server,
    poll_tls,
    has_active_tls,
)
from tsonic_node.net import (
    ConnectionOptions as TcpOptions,
    create_connection_options,
    poll_net,
)


@fieldwise_init
struct Counter:
    var count: Location[Int]
    var throws: Bool

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var state = context.unsafe_bitcast[Counter]()
        state[].count.write(state[].count.read() + 1)
        if state[].throws:
            raise Error("selected TLS listener failure")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Counter](context)


def notification(
    count: Location[Int], throws: Bool = False
) -> RaisingCallable[Tuple[], NoneType]:
    var context = allocate_callable_environment(
        Counter(count, throws), Counter.destroy
    )
    return RaisingCallable[Tuple[], NoneType](context, Counter.invoke)


@fieldwise_init
struct Receiver:
    var socket: Location[Optional[TLSSocket]]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[TLSSocket]
    ) raises:
        context.unsafe_bitcast[Receiver]()[].socket.write(arguments[0])

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Receiver](context)


def receiver(
    socket: Location[Optional[TLSSocket]],
) -> RaisingCallable[Tuple[TLSSocket], NoneType]:
    var context = allocate_callable_environment(
        Receiver(socket), Receiver.destroy
    )
    return RaisingCallable[Tuple[TLSSocket], NoneType](context, Receiver.invoke)


@fieldwise_init
struct Failure:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[TsError, TLSSocket]
    ) raises:
        var state = context.unsafe_bitcast[Failure]()
        assert_true(arguments[1].closed())
        state[].count.write(state[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Failure](context)


def main() raises:
    var certificate = read_text_file("tests/fixtures/localhost-cert.pem")
    var key = read_text_file("tests/fixtures/localhost-key.pem")
    var server = create_server(
        TlsOptions(key=key, cert=certificate, allow_half_open=True)
    )
    var peer = Location(Optional[TLSSocket]())
    _ = server.once_connection("secureConnection", receiver(peer))
    _ = server.listen(0, "127.0.0.1")
    var authorities = List[String]()
    authorities.append(certificate)
    var client = connect(
        ConnectionOptions(
            host="127.0.0.1",
            servername="localhost",
            port=server.address().value().port,
            ca=authorities,
            allow_half_open=True,
        )
    )
    var secured = Location(0)
    _ = client.once_empty("secureConnect", notification(secured, True))
    var failures = 0
    var deadline = monotonic_milliseconds() + 5000
    while (
        not peer.read() or secured.read() == 0
    ) and monotonic_milliseconds() < deadline:
        try:
            _ = poll_tls()
        except error:
            assert_equal(String(error), "selected TLS listener failure")
            failures += 1
        sleep(0.001)
    assert_equal(secured.read(), 1)
    assert_equal(failures, 1)
    assert_true(Bool(peer.read()))
    assert_false(client.closed())
    assert_false(peer.read().value().closed())
    assert_true(client.servername_value().value().isa[String]())
    assert_equal(client.servername_value().value().get[String](), "localhost")
    assert_true(client.alpn_protocol().isa[Bool]())
    assert_false(client.alpn_protocol().get[Bool]())
    var timeouts = Location(0)
    var timed_out = notification(timeouts)
    _ = client.set_timeout_callback(1.5, timed_out)
    deadline = monotonic_milliseconds() + 5000
    while timeouts.read() == 0 and monotonic_milliseconds() < deadline:
        _ = poll_tls()
        sleep(0.001)
    assert_equal(timeouts.read(), 1)
    assert_false(client.closed())
    _ = client.set_timeout_callback(1.5, timed_out)
    _ = client.set_timeout_callback(0, timed_out)
    sleep(0.005)
    _ = poll_tls()
    assert_equal(timeouts.read(), 1)
    _ = client.set_no_delay().pause()
    assert_true(client.is_paused())
    _ = client.resume()
    var closed = Location(0)
    _ = server.once_empty("close", notification(closed))
    _ = server.close()
    _ = poll_tls()
    assert_equal(closed.read(), 0)
    _ = client.destroy()
    _ = peer.read().value().destroy()
    _ = poll_tls()
    assert_equal(closed.read(), 1)
    assert_false(has_active_tls())
    _ = server.listen(0, "127.0.0.1")
    _ = server.close()
    _ = poll_tls()
    assert_false(has_active_tls())
    prove_idle_timeout_during_handshake()
    prove_server_handshake_timeout(certificate, key)


def prove_idle_timeout_during_handshake() raises:
    var server = NetworkEndpoint("127.0.0.1", 0, True)
    var client = connect(
        ConnectionOptions(
            host="127.0.0.1",
            port=server.address().value().port,
            ca=List[String](),
            reject_unauthorized=False,
            timeout=1.5,
        )
    )
    var fired = Location(0)
    _ = client.once_empty("timeout", notification(fired))
    var deadline = monotonic_milliseconds() + 5000
    var peer = Optional[NetworkEndpoint]()
    while fired.read() == 0 and monotonic_milliseconds() < deadline:
        _ = poll_tls()
        if not peer:
            peer = server.accept()
        sleep(0.001)
    assert_equal(fired.read(), 1)
    assert_false(client.ready())
    assert_false(client.closed())
    _ = client.destroy()
    if peer:
        peer.value().close()
    server.close()
    _ = poll_tls()


def prove_server_handshake_timeout(certificate: String, key: String) raises:
    var server = create_server(
        TlsOptions(key=key, cert=certificate, handshake_timeout=1.5)
    )
    var failures = Location(0)
    var context = allocate_callable_environment(
        Failure(failures), Failure.destroy
    )
    _ = server.on_tls_client_error(
        "tlsClientError",
        RaisingCallable[Tuple[TsError, TLSSocket], NoneType](
            context, Failure.invoke
        ),
    )
    _ = server.listen(0, "127.0.0.1")
    var client = create_connection_options(
        TcpOptions(server.address().value().port, "127.0.0.1")
    )
    var deadline = monotonic_milliseconds() + 5000
    while failures.read() == 0 and monotonic_milliseconds() < deadline:
        _ = poll_net()
        _ = poll_tls()
        sleep(0.001)
    assert_equal(failures.read(), 1)
    _ = client.destroy()
    _ = server.close()
    _ = poll_tls()
    _ = poll_net()
