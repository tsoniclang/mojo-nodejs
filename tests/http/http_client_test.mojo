from std.collections import List
from std.testing import assert_equal, assert_true
from std.time import sleep
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.buffer import Buffer
from tsonic_node.filesystem import read_text_file
from tsonic_node.http import (
    IncomingMessage,
    ServerResponse,
    create_server,
    poll_servers,
)
from tsonic_node.http.client import (
    get,
    request,
    has_pending_requests,
    poll_requests,
)
from tsonic_node.http.client_options import RequestOptions
from tsonic_node.http.connections import has_pending_connections
from tsonic_node.https import (
    create_server as create_https_server,
    request as https_request,
)
from tsonic_node.tls import TlsOptions, poll_tls, create_secure_context, SecureContextOptions


@fieldwise_init
struct Listen:
    @staticmethod
    def invoke(context: ErasedCallableContext, var arguments: Tuple[]) raises:
        pass

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Listen](context)


@fieldwise_init
struct Handler:
    var calls: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[IncomingMessage, ServerResponse],
    ) raises:
        var owner = context.unsafe_bitcast[Handler]()
        var incoming = arguments[0]
        var response = arguments[1]
        owner[].calls.write(owner[].calls.read() + 1)
        response.set_header("Content-Type", "application/octet-stream")
        if incoming.url == "/echo?query=1":
            assert_equal(incoming.method, "POST")
            var bytes = incoming.read_all_buffer()
            assert_equal(len(bytes), 3 * 1024 * 1024)
            response.set_status_code(201)
            response.end_buffer(bytes)
        elif incoming.url == "/head":
            assert_equal(incoming.method, "HEAD")
            response.end_string("not transmitted")
        else:
            response.end_string("alive")

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Handler](context)


@fieldwise_init
struct Completion:
    var calls: Location[Int]
    var body: Location[Buffer]
    var status: Location[Int32]
    var fail: Bool

    @staticmethod
    def invoke(
        context: ErasedCallableContext, var arguments: Tuple[IncomingMessage]
    ) raises:
        var owner = context.unsafe_bitcast[Completion]()
        owner[].calls.write(owner[].calls.read() + 1)
        if owner[].fail:
            raise Error("intentional completion callback failure")
        owner[].status.write(arguments[0].status_code.value())
        owner[].body.write(arguments[0].read_all_buffer())
        assert_equal(len(arguments[0].read_all_buffer()), 0)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Completion](context)


def listen_callback() -> RaisingCallable[Tuple[], NoneType]:
    var owner = allocate_callable_environment(Listen(), Listen.destroy)
    return RaisingCallable[Tuple[], NoneType](owner, Listen.invoke)


def handler(
    calls: Location[Int],
) -> RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType]:
    var owner = allocate_callable_environment(Handler(calls), Handler.destroy)
    return RaisingCallable[Tuple[IncomingMessage, ServerResponse], NoneType](
        owner, Handler.invoke
    )


def completion(
    calls: Location[Int],
    body: Location[Buffer],
    status: Location[Int32],
    fail: Bool = False,
) -> RaisingCallable[Tuple[IncomingMessage], NoneType]:
    var owner = allocate_callable_environment(
        Completion(calls, body, status, fail), Completion.destroy
    )
    return RaisingCallable[Tuple[IncomingMessage], NoneType](
        owner, Completion.invoke
    )


def pump() raises:
    for _ in range(10000):
        _ = poll_requests()
        _ = poll_tls()
        _ = poll_servers()
        if not has_pending_requests() and not has_pending_connections():
            return
        sleep(0.001)
    raise Error(
        "Same-process HTTP/TLS requests failed to make bounded progress"
    )


def large_body() -> Buffer:
    var bytes = List[Byte](capacity=3 * 1024 * 1024)
    for index in range(3 * 1024 * 1024):
        bytes.append(Byte(index % 251))
    return Buffer(bytes^)


def main() raises:
    var calls = Location(0)
    var server = create_server(handler(calls))
    _ = server.listen(Int32(18101), "127.0.0.1", listen_callback())
    var options = RequestOptions()
    options.hostname = Optional("127.0.0.1")
    options.port = Optional(Float64(18101))
    options.path = Optional("/echo?query=1")
    options.method = Optional("POST")
    var received = Location(Buffer())
    var completed = Location(0)
    var status = Location(Int32(0))
    var client = request(options, completion(completed, received, status))
    assert_equal(client.path(), "/echo?query=1")
    assert_equal(client.method(), "POST")
    assert_equal(client.host(), "127.0.0.1")
    assert_equal(client.protocol(), "http:")
    client.set_header("X-Example", "before")
    client.set_header("x-example", "after")
    client.remove_header("X-Example")
    var injection_rejected = False
    try:
        client.set_header("X-Example", "bad\r\nInjected: true")
    except:
        injection_rejected = True
    assert_true(injection_rejected)
    var expected = large_body()
    _ = client.end_buffer(expected)
    _ = client.end()
    pump()
    assert_equal(completed.read(), 1)
    assert_equal(status.read(), 201)
    assert_equal(received.read().copy_bytes(), expected.copy_bytes())
    var head_options = RequestOptions()
    head_options.hostname = Optional("127.0.0.1")
    head_options.port = Optional(Float64(18101))
    head_options.path = Optional("/head")
    head_options.method = Optional("HEAD")
    _ = request(head_options, completion(completed, received, status)).end()
    pump()
    assert_equal(completed.read(), 2)
    assert_equal(len(received.read()), 0)
    var discarded = Location(0)
    var cancelled = get(
        "http://127.0.0.1:18101/cancel", completion(discarded, received, status)
    )
    _ = cancelled.destroy()
    pump()
    assert_equal(discarded.read(), 0)
    var failures = Location(0)
    var survivors = Location(0)
    _ = get(
        "http://127.0.0.1:18101/first",
        completion(failures, received, status, True),
    )
    _ = get(
        "http://127.0.0.1:18101/second", completion(survivors, received, status)
    )
    var propagated = False
    try:
        pump()
    except error:
        assert_equal(String(error), "intentional completion callback failure")
        propagated = True
    assert_true(propagated)
    pump()
    assert_equal(failures.read(), 1)
    assert_equal(survivors.read(), 1)
    assert_equal(received.read().to_string(), "alive")
    server.close()
    var secure_options = TlsOptions()
    secure_options.cert = Optional(
        read_text_file("tests/fixtures/localhost-cert.pem")
    )
    secure_options.key = Optional(
        read_text_file("tests/fixtures/localhost-key.pem")
    )
    var secure = create_https_server(secure_options, handler(calls))
    _ = secure.listen(Float64(18102), "127.0.0.1", listen_callback())
    options.hostname = Optional("localhost")
    options.port = Optional(Float64(18102))
    _ = https_request(
        options, completion(completed, received, status)
    ).end_buffer(expected)
    pump()
    assert_equal(completed.read(), 3)
    assert_equal(status.read(), 201)
    assert_equal(received.read().copy_bytes(), expected.copy_bytes())
    var authorities = List[String]()
    authorities.append(secure_options.cert.value())
    var context_options = SecureContextOptions(ca=Optional(authorities^), min_version="TLSv1.2", max_version="TLSv1.3")
    options.secure_context = Optional(create_secure_context(context_options))
    options.min_version = Optional("not-selected-with-an-explicit-context")
    _ = https_request(options, completion(completed, received, status)).end_buffer(expected)
    pump()
    assert_equal(completed.read(), 4)
    assert_equal(status.read(), 201)
    assert_equal(received.read().copy_bytes(), expected.copy_bytes())
    secure.close()
