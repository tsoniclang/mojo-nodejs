from std.collections import List
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
from tsonic_node.http import (
    IncomingMessage,
    ServerResponse,
    create_server,
    poll_servers,
)


@fieldwise_init
struct RequestEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[IncomingMessage, ServerResponse],
    ) raises -> None:
        var environment = context.unsafe_bitcast[RequestEnvironment]()
        assert_equal(arguments[0].method, "GET")
        assert_equal(arguments[0].url, "/health")
        arguments[1].set_header("Content-Type", "text/plain")
        arguments[1].end_string("ready")
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[RequestEnvironment](context)


@fieldwise_init
struct ListenEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[],
    ) raises -> None:
        var environment = context.unsafe_bitcast[ListenEnvironment]()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[ListenEnvironment](context)


def request_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType]:
    var owner = allocate_callable_environment(
        RequestEnvironment(count), RequestEnvironment.destroy
    )
    return RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType](
        owner, RequestEnvironment.invoke
    )


def listen_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[], NoneType]:
    var owner = allocate_callable_environment(
        ListenEnvironment(count), ListenEnvironment.destroy
    )
    return RaisingCallable[Tuple[], NoneType](owner, ListenEnvironment.invoke)


def main() raises:
    comptime port = 18081
    var requests = Location(0)
    var listens = Location(0)
    var server = create_server(request_callback(requests))
    _ = server.listen(Int32(port), "127.0.0.1", listen_callback(listens))

    var child = external_call["fork", c_pid_t]()
    if child == 0:
        _run_client(port)
        external_call["_exit", NoneType](c_int(0))

    for _ in range(500):
        _ = poll_servers()
        if requests.read() == 1:
            break
        sleep(0.002)
    server.close()
    var status: c_int = 0
    assert_true(waitpid(child, Pointer(to=status), 0) >= 0)
    assert_equal(status, 0)
    assert_equal(listens.read(), 1)
    assert_equal(requests.read(), 1)


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
    var request = (
        "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )
    var sent = external_call["send", c_ssize_t](
        descriptor,
        request.as_bytes().unsafe_ptr(),
        c_size_t(request.byte_length()),
        c_int(0),
    )
    if sent != request.byte_length():
        external_call["_exit", NoneType](c_int(12))
    var response = List[Byte]()
    var buffer = Array[Byte, 4096](fill=0)
    while True:
        var count = external_call["recv", c_ssize_t](
            descriptor, buffer.unsafe_ptr(), c_size_t(4096), c_int(0)
        )
        if count <= 0:
            break
        for index in range(count):
            response.append(buffer[index])
    _ = close(descriptor)
    var text = String(from_utf8=response)
    if text.find("HTTP/1.1 200 OK") < 0 or not text.endswith("ready"):
        external_call["_exit", NoneType](c_int(13))
