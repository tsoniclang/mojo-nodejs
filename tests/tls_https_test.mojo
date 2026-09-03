from std.collections import List
from std.ffi import c_int, c_pid_t, external_call
from std.sys._libc import waitpid
from std.testing import assert_equal, assert_true
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.filesystem import read_text_file
from tsonic_node.http import IncomingMessage, ServerResponse
from tsonic_node.https import (
    create_server as create_https_server,
    get as https_get,
    poll_https,
)
from tsonic_node.tls import (
    ConnectionOptions,
    TLSSocket,
    TlsOptions,
    connect,
    create_server as create_tls_server,
    poll_tls,
)


@fieldwise_init
struct EmptyEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[]) raises:
        var environment = context.unsafe_bitcast[EmptyEnvironment]()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[EmptyEnvironment](context)


@fieldwise_init
struct SocketEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[TLSSocket]
    ) raises:
        var environment = context.unsafe_bitcast[SocketEnvironment]()
        var socket = arguments[0]
        var input = socket.read()
        assert_true(input)
        assert_equal(input.value().to_string(), "ping")
        assert_true(socket.write_string("pong"))
        socket.end()
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[SocketEnvironment](context)


@fieldwise_init
struct RequestEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[IncomingMessage, ServerResponse],
    ) raises:
        var environment = context.unsafe_bitcast[RequestEnvironment]()
        assert_equal(arguments[0].method, "GET")
        assert_equal(arguments[0].url, "/")
        arguments[1].end_string("secure")
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[RequestEnvironment](context)


@fieldwise_init
struct ResponseEnvironment:
    var body: Location[String]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[IncomingMessage],
    ) raises:
        var environment = context.unsafe_bitcast[ResponseEnvironment]()
        environment[].body.write(arguments[0].read_all())

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[ResponseEnvironment](context)


def empty_callback(count: Location[Int]) -> RaisingCallable[Tuple[], NoneType]:
    var environment = allocate_callable_environment(
        EmptyEnvironment(count), EmptyEnvironment.destroy
    )
    return RaisingCallable[Tuple[], NoneType](
        environment, EmptyEnvironment.invoke
    )


def socket_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[TLSSocket], NoneType]:
    var environment = allocate_callable_environment(
        SocketEnvironment(count), SocketEnvironment.destroy
    )
    return RaisingCallable[Tuple[TLSSocket], NoneType](
        environment, SocketEnvironment.invoke
    )


def request_callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType]:
    var environment = allocate_callable_environment(
        RequestEnvironment(count), RequestEnvironment.destroy
    )
    return RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType](
        environment, RequestEnvironment.invoke
    )


def response_callback(
    body: Location[String],
) -> RaisingCallable[Tuple[IncomingMessage], NoneType]:
    var environment = allocate_callable_environment(
        ResponseEnvironment(body), ResponseEnvironment.destroy
    )
    return RaisingCallable[Tuple[IncomingMessage], NoneType](
        environment, ResponseEnvironment.invoke
    )


def main() raises:
    var certificate = read_text_file("tests/fixtures/localhost-cert.pem")
    var private_key = read_text_file("tests/fixtures/localhost-key.pem")
    _prove_tls(certificate, private_key)
    _prove_https(certificate, private_key)


def _prove_tls(certificate: String, private_key: String) raises:
    comptime port = 18083
    var options = TlsOptions()
    options.cert = Optional(certificate)
    options.key = Optional(private_key)
    var accepted = Location(0)
    var listening = Location(0)
    var server = create_tls_server(options, socket_callback(accepted))
    _ = server.listen(Float64(port), "127.0.0.1", empty_callback(listening))

    var child = external_call["fork", c_pid_t]()
    if child == 0:
        try:
            _run_tls_client(port, certificate)
            external_call["_exit", NoneType](c_int(0))
        except:
            external_call["_exit", NoneType](c_int(20))

    _poll_server(accepted)
    server.close()
    var status: c_int = 0
    assert_true(waitpid(child, Pointer(to=status), 0) >= 0)
    assert_equal(status, 0)
    assert_equal(listening.read(), 1)
    assert_equal(accepted.read(), 1)


def _run_tls_client(port: Int, certificate: String) raises:
    sleep(0.02)
    var certificates = List[String]()
    certificates.append(certificate)
    var options = ConnectionOptions(
        host=Optional("127.0.0.1"),
        servername=Optional("localhost"),
        port=Optional(Float64(port)),
        ca=Optional(certificates^),
        reject_unauthorized=Optional(True),
    )
    var socket = connect(options)
    assert_true(socket.authorized())
    assert_true(socket.write_string("ping"))
    var output = socket.read()
    assert_true(output)
    assert_equal(output.value().to_string(), "pong")
    socket.end()


def _prove_https(certificate: String, private_key: String) raises:
    comptime port = 18084
    var options = TlsOptions()
    options.cert = Optional(certificate)
    options.key = Optional(private_key)
    var handled = Location(0)
    var listening = Location(0)
    var server = create_https_server(options, request_callback(handled))
    _ = server.listen(Float64(port), "127.0.0.1", empty_callback(listening))

    var child = external_call["fork", c_pid_t]()
    if child == 0:
        try:
            _run_https_client(port)
            external_call["_exit", NoneType](c_int(0))
        except:
            external_call["_exit", NoneType](c_int(21))

    _poll_server(handled)
    server.close()
    var status: c_int = 0
    assert_true(waitpid(child, Pointer(to=status), 0) >= 0)
    assert_equal(status, 0)
    assert_equal(listening.read(), 1)
    assert_equal(handled.read(), 1)


def _run_https_client(port: Int) raises:
    sleep(0.02)
    var body = Location(String())
    _ = https_get(
        "https://localhost:" + String(port) + "/",
        response_callback(body),
    )
    assert_true(poll_https())
    assert_equal(body.read(), "secure")


def _poll_server(count: Location[Int]) raises:
    for _ in range(500):
        _ = poll_tls()
        if count.read() == 1:
            return
        sleep(0.002)
    raise Error("TLS server did not receive the expected connection")
