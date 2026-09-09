from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import (
    ErasedCallableContext,
    GlobalCell,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)

from .buffer import Buffer
from .http.client import ClientRequest, ResponseCallback, request_for_scheme
from .http.client_options import RequestOptions
from .http.messages import IncomingMessage, ServerResponse
from .http.parsing import (
    find_header_end,
    parse_request_bytes,
    request_content_length,
)
from .tls import (
    EmptyCallback,
    Server as TlsServer,
    TLSSocket,
    TlsOptions,
    create_server as create_tls_server,
    connect as tls_connect,
    ConnectionOptions,
)


comptime RequestArguments = Tuple[IncomingMessage, ServerResponse]
comptime RequestHandler = RaisingCallable[RequestArguments, NoneType]

comptime _MAX_MESSAGE_BYTES = 268_435_456
comptime _MAX_PENDING = 1 << 20


@fieldwise_init
struct _HttpsServerAdapter:
    var handler: RequestHandler

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[TLSSocket],
    ) raises:
        var pointer = context.unsafe_bitcast[_HttpsServerAdapter]()
        _accept_request(pointer[].handler, arguments[0])

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[_HttpsServerAdapter](context)


struct Server(ImplicitlyCopyable):
    var _server: TlsServer

    def __init__(out self, server: TlsServer):
        self._server = server

    def listen_default_host(
        self, port: Float64, callback: EmptyCallback
    ) raises -> Self:
        _ = self._server.listen_default_host(port, callback)
        return self

    def listen(
        self, port: Float64, host: String, callback: EmptyCallback
    ) raises -> Self:
        _ = self._server.listen(port, host, callback)
        return self

    def close(self):
        self._server.close()

    def ref(self) -> Self:
        _ = self._server.ref()
        return self

    def unref(self) -> Self:
        _ = self._server.unref()
        return self

    def listening(self) -> Bool:
        return self._server.listening()


def _initial_responses() -> List[ServerResponse]:
    return List[ServerResponse]()


comptime _responses = GlobalCell[
    "tsonic.node.https.responses", _initial_responses
]()
def create_server(
    options: TlsOptions, handler: RequestHandler
) raises -> Server:
    var environment = allocate_callable_environment(
        _HttpsServerAdapter(handler), _HttpsServerAdapter.destroy
    )
    var callback = RaisingCallable[Tuple[TLSSocket], NoneType](
        environment, _HttpsServerAdapter.invoke
    )
    return Server(create_tls_server(options, callback))


def has_active_https() -> Bool:
    return len(_responses.get()[]) != 0


def poll_https() raises -> Bool:
    var did_work = False
    var retained = List[ServerResponse]()
    for response in _responses.get()[]:
        if not response.is_finished():
            retained.append(response)
    if len(retained) != len(_responses.get()[]):
        did_work = True
    _responses.get()[] = retained^
    return did_work


def _accept_request(handler: RequestHandler, socket: TLSSocket) raises:
    var bytes = List[Byte]()
    var header_end = -1
    while header_end < 0:
        _read_tls_chunk(socket, bytes)
        header_end = find_header_end(bytes)
        if len(bytes) > 64 * 1024:
            raise Error("HTTPS request headers exceed the finite runtime limit")
    var content_length = request_content_length(bytes, header_end)
    while len(bytes) - header_end - 4 < content_length:
        _read_tls_chunk(socket, bytes)
    var request_value = parse_request_bytes(bytes)
    var response = ServerResponse(socket)
    handler.call((request_value, response))
    if not response.is_finished():
        if len(_responses.get()[]) >= _MAX_PENDING:
            response.end_empty()
            raise Error(
                "Pending HTTPS responses exceed the finite runtime limit"
            )
        _responses.get()[].append(response)


def _read_tls_chunk(socket: TLSSocket, mut bytes: List[Byte]) raises:
    var chunk = socket.read()
    if not chunk:
        raise Error("HTTPS message ended before it was complete")
    if len(bytes) + len(chunk.value()) > _MAX_MESSAGE_BYTES:
        raise Error("HTTPS message exceeds the finite runtime limit")
    for value in chunk.value().copy_bytes():
        bytes.append(value)


def request(url: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request_for_scheme(url, "https:", callback)


def request(options: RequestOptions, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request_for_scheme(options, "https:", callback)


def get(url: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request(url, callback).end()


def get(options: RequestOptions, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request(options, callback).end()
