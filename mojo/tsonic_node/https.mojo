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
comptime ResponseCallback = RaisingCallable[Tuple[IncomingMessage], NoneType]

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


struct _ClientRequestState:
    var url: String
    var callback: ResponseCallback
    var body: List[Byte]
    var ended: Bool

    def __init__(out self, url: String, callback: ResponseCallback):
        self.url = url
        self.callback = callback
        self.body = List[Byte]()
        self.ended = False


struct ClientRequest(ImplicitlyCopyable):
    var _state: ArcPointer[_ClientRequestState]

    def __init__(out self, url: String, callback: ResponseCallback):
        self._state = ArcPointer(_ClientRequestState(url, callback))

    def write_string(self, value: String) raises -> Bool:
        if self._state[].ended:
            raise Error("write after end")
        if len(self._state[].body) + value.byte_length() > _MAX_MESSAGE_BYTES:
            raise Error("HTTPS request body exceeds the finite runtime limit")
        for byte in value.as_bytes():
            self._state[].body.append(byte)
        return True

    def end(self) raises:
        if self._state[].ended:
            return
        self._state[].ended = True
        var body = List[Byte](capacity=len(self._state[].body))
        for value in self._state[].body:
            body.append(value)
        var response = _perform_request(self._state[].url, Buffer(body^))
        _enqueue_response(response, self._state[].callback)


@fieldwise_init
struct _PendingResponse(ImplicitlyCopyable):
    var response: IncomingMessage
    var callback: ResponseCallback


def _initial_responses() -> List[ServerResponse]:
    return List[ServerResponse]()


def _initial_callbacks() -> List[_PendingResponse]:
    return List[_PendingResponse]()


comptime _responses = GlobalCell[
    "tsonic.node.https.responses", _initial_responses
]()
comptime _callbacks = GlobalCell[
    "tsonic.node.https.callbacks", _initial_callbacks
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


def request(url: String, callback: ResponseCallback) -> ClientRequest:
    return ClientRequest(url, callback)


def get(url: String, callback: ResponseCallback) raises -> ClientRequest:
    var result = ClientRequest(url, callback)
    result.end()
    return result^


def has_active_https() -> Bool:
    return len(_callbacks.get()[]) != 0 or len(_responses.get()[]) != 0


def poll_https() raises -> Bool:
    var did_work = False
    if len(_callbacks.get()[]) != 0:
        var callbacks = List[_PendingResponse]()
        for pending in _callbacks.get()[]:
            callbacks.append(pending)
        _callbacks.get()[] = List[_PendingResponse]()
        for pending in callbacks:
            pending.callback.call((pending.response,))
        did_work = True
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


def _perform_request(url: String, body: Buffer) raises -> IncomingMessage:
    var location = _parse_url(url)
    var protocols = List[String]()
    protocols.append("http/1.1")
    var socket = tls_connect(
        ConnectionOptions(
            host=Optional(location.host),
            servername=Optional(location.host),
            port=Optional(Float64(location.port)),
            alpn_protocols=Optional(protocols^),
            reject_unauthorized=Optional(True),
        )
    )
    var request_head = (
        "GET "
        + location.path
        + " HTTP/1.1\r\nHost: "
        + location.host
        + "\r\nConnection: close\r\nContent-Length: "
        + String(len(body))
        + "\r\n\r\n"
    )
    _ = socket.write_string(request_head)
    if len(body) != 0:
        _ = socket.write_buffer(body)
    var bytes = List[Byte]()
    while True:
        var chunk = socket.read()
        if not chunk:
            break
        if len(bytes) + len(chunk.value()) > _MAX_MESSAGE_BYTES:
            raise Error("HTTPS response exceeds the finite runtime limit")
        for value in chunk.value().copy_bytes():
            bytes.append(value)
    socket.end()
    return _parse_response(url, bytes)


@fieldwise_init
struct _HttpsLocation(Copyable):
    var host: String
    var port: Int32
    var path: String


def _parse_url(url: String) raises -> _HttpsLocation:
    if not url.startswith("https://"):
        raise Error("HTTPS request requires an https:// URL")
    var remainder = String(url[byte=8:])
    var slash = remainder.find("/")
    var authority = String(
        remainder[byte = : slash.value()]
    ) if slash else remainder
    var path = String(remainder[byte = slash.value() :]) if slash else "/"
    if authority.byte_length() == 0:
        raise Error("HTTPS URL has no host")
    var host = authority
    var port = Int32(443)
    if authority.startswith("["):
        var closing = authority.find("]")
        if not closing:
            raise Error("HTTPS URL contains an invalid IPv6 host")
        host = String(authority[byte = 1 : closing.value()])
        if closing.value() + 1 < authority.byte_length():
            if (
                String(
                    authority[byte = closing.value() + 1 : closing.value() + 2]
                )
                != ":"
            ):
                raise Error("HTTPS URL authority is invalid")
            port = _parse_port(String(authority[byte = closing.value() + 2 :]))
    else:
        var separator = authority.rfind(":")
        if separator:
            host = String(authority[byte = : separator.value()])
            port = _parse_port(
                String(authority[byte = separator.value() + 1 :])
            )
    return _HttpsLocation(host, port, path)


def _parse_port(value: String) raises -> Int32:
    var port = Int(value)
    if port < 0 or port > 65535:
        raise Error("HTTPS URL port must be from 0 through 65535")
    return Int32(port)


def _parse_response(url: String, bytes: List[Byte]) raises -> IncomingMessage:
    var header_end = find_header_end(bytes)
    if header_end < 0:
        raise Error("HTTPS response has incomplete headers")
    var head_bytes = List[Byte](capacity=header_end)
    for index in range(header_end):
        head_bytes.append(bytes[index])
    var lines = String(from_utf8=head_bytes).split("\r\n")
    if len(lines) == 0 or not String(lines[0]).startswith("HTTP/"):
        raise Error("HTTPS response status line is invalid")
    var chunked = False
    var content_length: Optional[Int] = None
    for index in range(1, len(lines)):
        var line = String(lines[index])
        var separator = line.find(":")
        if not separator:
            raise Error("HTTPS response header is invalid")
        var name = String(line[byte = : separator.value()]).lower()
        var value = String(line[byte = separator.value() + 1 :]).strip()
        if name == "transfer-encoding" and value.lower() == "chunked":
            chunked = True
        if name == "content-length":
            content_length = Optional(Int(value))
    var body_start = header_end + 4
    var body = _decode_chunked(bytes, body_start) if chunked else _copy_body(
        bytes, body_start, content_length
    )
    return IncomingMessage("GET", url, Buffer(body^))


def _copy_body(
    bytes: List[Byte], start: Int, expected: Optional[Int]
) raises -> List[Byte]:
    var length = expected.value() if expected else len(bytes) - start
    if length < 0 or start + length > len(bytes):
        raise Error("HTTPS response body is incomplete")
    var output = List[Byte](capacity=length)
    for index in range(length):
        output.append(bytes[start + index])
    return output^


def _decode_chunked(bytes: List[Byte], start: Int) raises -> List[Byte]:
    var output = List[Byte]()
    var cursor = start
    while True:
        var line_end = _find_crlf(bytes, cursor)
        if line_end < 0:
            raise Error("HTTPS chunk size is incomplete")
        var size_bytes = List[Byte](capacity=line_end - cursor)
        for index in range(cursor, line_end):
            size_bytes.append(bytes[index])
        var size_text = String(from_utf8=size_bytes)
        var extension = size_text.find(";")
        if extension:
            var without_extension = String(
                size_text[byte = : extension.value()]
            )
            size_text = without_extension^
        var normalized_size = String(size_text.strip())
        var size = _hex_size(normalized_size)
        cursor = line_end + 2
        if size == 0:
            return output^
        if size < 0 or cursor + size + 2 > len(bytes):
            raise Error("HTTPS chunk data is incomplete")
        if len(output) + size > _MAX_MESSAGE_BYTES:
            raise Error("HTTPS response body exceeds the finite runtime limit")
        for index in range(size):
            output.append(bytes[cursor + index])
        cursor += size
        if bytes[cursor] != 13 or bytes[cursor + 1] != 10:
            raise Error("HTTPS chunk terminator is invalid")
        cursor += 2


def _find_crlf(bytes: List[Byte], start: Int) -> Int:
    if start < 0 or start >= len(bytes):
        return -1
    for index in range(start, len(bytes) - 1):
        if bytes[index] == 13 and bytes[index + 1] == 10:
            return index
    return -1


def _hex_size(value: String) raises -> Int:
    if value.byte_length() == 0:
        raise Error("HTTPS chunk size is empty")
    var result = 0
    for byte in value.as_bytes():
        var digit = (
            Int(byte) - 48 if byte >= 48
            and byte <= 57 else Int(byte) - 87 if byte >= 97
            and byte <= 102 else Int(byte) - 55 if byte >= 65
            and byte <= 70 else -1
        )
        if digit < 0:
            raise Error("HTTPS chunk size is invalid")
        if result > (_MAX_MESSAGE_BYTES - digit) // 16:
            raise Error("HTTPS chunk size exceeds the finite runtime limit")
        result = result * 16 + digit
    return result


def _enqueue_response(
    response: IncomingMessage, callback: ResponseCallback
) raises:
    if len(_callbacks.get()[]) >= _MAX_PENDING:
        raise Error("Pending HTTPS callbacks exceed the finite runtime limit")
    _callbacks.get()[].append(_PendingResponse(response, callback))
