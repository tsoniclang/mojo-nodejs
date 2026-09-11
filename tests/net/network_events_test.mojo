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
from tsonic_node.internal.network_endpoint import monotonic_milliseconds
from tsonic_node.net import (
    ConnectionOptions,
    ListenOptions,
    Socket,
    create_server,
    create_server_callback,
    poll_net,
    has_active_net,
)


@fieldwise_init
struct Counter:
    var count: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var environment = context.unsafe_bitcast[Counter]()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Counter](context)


def notification(count: Location[Int]) -> RaisingCallable[Tuple[], NoneType]:
    var environment = allocate_callable_environment(
        Counter(count), Counter.destroy
    )
    return RaisingCallable[Tuple[], NoneType](environment, Counter.invoke)


@fieldwise_init
struct Receiver:
    var peer: Location[Optional[Socket]]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[Socket]
    ) raises:
        context.unsafe_bitcast[Receiver]()[].peer.write(arguments[0])

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Receiver](context)


def main() raises:
    var closed = Location(0)
    var unused = create_server()
    _ = unused.once_empty("close", notification(closed))
    _ = unused.close()
    assert_equal(closed.read(), 0)
    _ = poll_net()
    assert_equal(closed.read(), 1)
    assert_false(has_active_net())

    var peer = Location(Optional[Socket]())
    var environment = allocate_callable_environment(
        Receiver(peer), Receiver.destroy
    )
    var server = create_server_callback(
        RaisingCallable[Tuple[Socket], NoneType](environment, Receiver.invoke)
    )
    var options = ListenOptions()
    options.port = 0
    options.host = "127.0.0.1"
    options.backlog = 8
    _ = server.listen_options(options)
    var client = Socket()
    var retained_client = client
    assert_true(client.pending())
    assert_false(client.connecting())
    assert_false(client.remote_address())
    assert_false(client.remote_port())
    var connected = Location(0)
    _ = client.once_empty("connect", notification(connected))
    _ = retained_client.connect_options(
        ConnectionOptions(server.address().value().port, "127.0.0.1")
    )
    assert_true(client.connecting())
    var deadline = monotonic_milliseconds() + 5000
    while (
        connected.read() == 0 or not peer.read()
    ) and monotonic_milliseconds() < deadline:
        _ = poll_net()
        sleep(0.001)
    assert_equal(connected.read(), 1)
    assert_false(retained_client.connecting())
    assert_equal(retained_client.remote_address().value(), "127.0.0.1")
    assert_equal(
        retained_client.remote_port().value(), server.address().value().port
    )
    var duplicate_rejected = False
    try:
        _ = retained_client.connect_port(server.address().value().port)
    except:
        duplicate_rejected = True
    assert_true(duplicate_rejected)
    assert_true(Bool(peer.read()))
    var timeouts = Location(0)
    var timed_out = notification(timeouts)
    _ = client.set_timeout_callback(1.5, timed_out)
    deadline = monotonic_milliseconds() + 5000
    while timeouts.read() == 0 and monotonic_milliseconds() < deadline:
        _ = poll_net()
        sleep(0.001)
    assert_equal(timeouts.read(), 1)
    assert_false(client.destroyed())
    _ = poll_net()
    assert_equal(timeouts.read(), 1)
    _ = client.set_timeout_callback(1.5, timed_out)
    _ = client.set_timeout_callback(0, timed_out)
    sleep(0.005)
    _ = poll_net()
    assert_equal(timeouts.read(), 1)
    _ = client.destroy()
    var accepted = peer.read().value()
    _ = accepted.destroy()
    _ = server.close()
    _ = poll_net()
    assert_true(client.pending())
    assert_false(retained_client.remote_address())
    assert_false(has_active_net())
