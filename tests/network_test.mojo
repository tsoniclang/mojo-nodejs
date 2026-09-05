from std.ffi import c_int, c_pid_t, c_size_t, c_ssize_t, external_call
from std.testing import assert_equal, assert_true
from std.time import sleep
from std.sys._libc import close, waitpid
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.dns import lookup, resolve4
from tsonic_node.net import (
    Socket,
    create_server_callback,
    is_ip,
    is_ipv4,
    is_ipv6,
    poll_net,
)


@fieldwise_init
struct ConnectionEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[Socket]
    ) raises:
        var environment = context.unsafe_bitcast[ConnectionEnvironment]()
        var socket = arguments[0]
        assert_equal(socket.read().to_string(), "ping")
        assert_true(socket.write_string("pong"))
        socket.end()
        socket.destroy()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[ConnectionEnvironment](context)


def connection_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[Socket], NoneType]:
    var environment = allocate_callable_environment(
        ConnectionEnvironment(count), ConnectionEnvironment.destroy
    )
    return RaisingCallable[Tuple[Socket], NoneType](
        environment, ConnectionEnvironment.invoke
    )


def main() raises:
    var local = lookup("localhost")
    assert_true(local.family == 4 or local.family == 6)
    assert_true(local.address.byte_length() != 0)
    assert_true(len(resolve4("localhost")) != 0)
    assert_equal(is_ip("127.0.0.1"), 4.0)
    assert_true(is_ipv4("127.0.0.1"))
    assert_true(is_ipv6("::1"))

    comptime port = 18082
    var accepted = Location(0)
    var server = create_server_callback(connection_callback(accepted))
    _ = server.listen_port_host(Float64(port), "127.0.0.1")

    var child = external_call["fork", c_pid_t]()
    if child == 0:
        _run_client(port)
        external_call["_exit", NoneType](c_int(0))

    for _ in range(500):
        _ = poll_net()
        if accepted.read() == 1:
            break
        sleep(0.002)
    server.close()
    var status: c_int = 0
    assert_true(waitpid(child, Pointer(to=status), 0) >= 0)
    assert_equal(status, 0)
    assert_equal(accepted.read(), 1)


def _run_client(port: Int) raises:
    sleep(0.02)
    var descriptor = external_call["socket", c_int](
        c_int(2), c_int(1), c_int(0)
    )
    if descriptor < 0:
        external_call["_exit", NoneType](c_int(10))
    var address = Array[UInt8, 16](fill=0)
    address[0] = 2
    address[2] = UInt8(port >> 8)
    address[3] = UInt8(port & 255)
    address[4] = 127
    address[7] = 1
    if (
        external_call["connect", c_int](
            descriptor, address.unsafe_ptr(), c_int(16)
        )
        != 0
    ):
        external_call["_exit", NoneType](c_int(11))
    var request = "ping"
    if (
        external_call["send", c_ssize_t](
            descriptor,
            request.as_bytes().unsafe_ptr(),
            c_size_t(request.byte_length()),
            c_int(0),
        )
        != request.byte_length()
    ):
        external_call["_exit", NoneType](c_int(12))
    var output = Array[Byte, 4](fill=0)
    var count = external_call["recv", c_ssize_t](
        descriptor, output.unsafe_ptr(), c_size_t(4), c_int(0)
    )
    _ = close(descriptor)
    if count != 4 or String(from_utf8=output) != "pong":
        external_call["_exit", NoneType](c_int(13))
