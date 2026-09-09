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
from tsonic_node.buffer import Buffer
from tsonic_node.http import IncomingMessage, ServerResponse
from tsonic_node.http.connections import has_pending_connections, poll_connections
from tsonic_node.http.client import has_pending_requests, poll_requests
from tsonic_node.https import (
    create_server as create_https_server,
    get as https_get,
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
    var socket: Location[Optional[TLSSocket]]
    var throw_on_accept: Bool

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[TLSSocket]
    ) raises:
        var environment = context.unsafe_bitcast[SocketEnvironment]()
        environment[].socket.write(Optional(arguments[0]))
        if environment[].throw_on_accept:
            raise Error("selected accept callback failure")

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
    socket: Location[Optional[TLSSocket]],
    throw_on_accept: Bool = False,
) -> RaisingCallable[Tuple[TLSSocket], NoneType]:
    var environment = allocate_callable_environment(
        SocketEnvironment(socket, throw_on_accept), SocketEnvironment.destroy
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
    _prove_throwing_accept(certificate, private_key)


def _prove_throwing_accept(certificate: String, private_key: String) raises:
    var server_options = TlsOptions(cert=Optional(certificate), key=Optional(private_key))
    var accepted = Location[Optional[TLSSocket]](None)
    var listening = Location(0)
    var server = create_tls_server(server_options, socket_callback(accepted, True))
    _ = server.listen(18093, "127.0.0.1", empty_callback(listening))
    var certificates = List[String]()
    certificates.append(certificate)
    var client = connect(ConnectionOptions(
        host=Optional("127.0.0.1"), servername=Optional("localhost"),
        port=Optional(Float64(18093)), ca=Optional(certificates^),
    ))
    var callback_failures = 0
    for _ in range(2000):
        try:
            _ = poll_tls()
        except error:
            assert_equal(String(error), "selected accept callback failure")
            callback_failures += 1
        if accepted.read() and client.ready():
            break
        sleep(0.001)
    assert_equal(callback_failures, 1)
    assert_true(accepted.read())
    var peer = accepted.read().value()
    assert_true(peer.ready())
    assert_true(not peer.closed())
    assert_true(peer.write_string("retained"))
    var response: Optional[Buffer] = None
    for _ in range(2000):
        _ = poll_tls()
        response = client.read()
        if response:
            break
        sleep(0.001)
    assert_true(response)
    assert_equal(response.value().to_string(), "retained")
    peer.destroy()
    client.destroy()
    server.close()


def _prove_tls(certificate: String, private_key: String) raises:
    comptime port = 18083
    var options = TlsOptions()
    options.cert = Optional(certificate)
    options.key = Optional(private_key)
    var accepted = Location[Optional[TLSSocket]](None)
    var listening = Location(0)
    var server = create_tls_server(options, socket_callback(accepted))
    _ = server.listen(Float64(port), "127.0.0.1", empty_callback(listening))

    var child = external_call["fork", c_pid_t]()
    if child == 0:
        server.close()
        try:
            _run_tls_client(port, certificate)
            external_call["_exit", NoneType](c_int(0))
        except:
            external_call["_exit", NoneType](c_int(20))

    var replied = False
    for _ in range(1000):
        _ = poll_tls()
        if accepted.read() and not replied:
            var socket = accepted.read().value()
            var input = socket.read()
            if input:
                assert_equal(input.value().to_string(), "ping")
                assert_true(socket.write_string("pong"))
                socket.end()
                replied = True
        if replied and accepted.read().value().closed():
            break
        sleep(0.002)
    assert_true(replied)
    assert_true(accepted.read().value().closed())
    server.close()
    var status: c_int = 0
    assert_true(waitpid(child, Pointer(to=status), 0) >= 0)
    assert_equal(status, 0)
    assert_equal(listening.read(), 1)


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
    for _ in range(1000):
        _ = poll_tls()
        if socket.ready():
            break
        sleep(0.002)
    assert_true(socket.ready())
    assert_true(socket.authorized())
    assert_true(socket.write_string("ping"))
    var output: Optional[Buffer] = None
    for _ in range(1000):
        _ = poll_tls()
        output = socket.read()
        if output:
            break
        sleep(0.002)
    assert_true(output)
    assert_equal(output.value().to_string(), "pong")
    socket.end()
    for _ in range(1000):
        _ = poll_tls()
        if socket.closed():
            break
        sleep(0.002)
    assert_true(socket.closed())


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
    for _ in range(500):
        _ = poll_requests()
        if not has_pending_requests():
            break
        sleep(0.002)
    assert_true(not has_pending_requests())
    assert_equal(body.read(), "secure")


def _poll_server(count: Location[Int]) raises:
    for _ in range(500):
        _ = poll_tls()
        _ = poll_connections()
        if count.read() == 1 and not has_pending_connections():
            return
        sleep(0.002)
    raise Error("TLS server did not receive the expected connection")
