from tsonic_runtime import (
    ErasedCallableContext,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)

from .http.client import ClientRequest, ResponseCallback, request_for_scheme
from .http.client_options import RequestOptions
from .http.messages import IncomingMessage, ServerResponse
from .http.connections import accept_connection
from .http.transport import HttpTransport
from .net.options import ListenOptions
from .tls import (
    EmptyCallback,
    Server as TlsServer,
    TLSSocket,
    TlsOptions,
    create_server as create_tls_server,
)


comptime RequestArguments = Tuple[IncomingMessage, ServerResponse]
comptime RequestHandler = RaisingCallable[RequestArguments, NoneType]


@fieldwise_init
struct _HttpsServerAdapter:
    var handler: RequestHandler

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[TLSSocket],
    ) raises:
        var pointer = context.unsafe_bitcast[_HttpsServerAdapter]()
        accept_connection(HttpTransport(arguments[0]), pointer[].handler)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[_HttpsServerAdapter](context)


struct Server(ImplicitlyCopyable):
    var _server: TlsServer

    def __init__(out self, server: TlsServer):
        self._server = server

    def listen_default_host(
        self, port: Float64, callback: Optional[EmptyCallback] = None
    ) raises -> Self:
        _ = self._server.listen_default_host(port, callback)
        return self

    def listen(
        self,
        port: Float64,
        host: String,
        callback: Optional[EmptyCallback] = None,
    ) raises -> Self:
        _ = self._server.listen(port, host, callback)
        return self

    def listen_options(
        self, options: ListenOptions, callback: Optional[EmptyCallback] = None
    ) raises -> Self:
        _ = self._server.listen_options(options, callback)
        return self

    def listen_backlog(
        self,
        port: Float64,
        backlog: Float64,
        callback: Optional[EmptyCallback] = None,
    ) raises -> Self:
        _ = self._server.listen_backlog(port, backlog, callback)
        return self

    def listen_host_backlog(
        self,
        port: Float64,
        host: String,
        backlog: Float64,
        callback: Optional[EmptyCallback] = None,
    ) raises -> Self:
        _ = self._server.listen_host_backlog(port, host, backlog, callback)
        return self

    def close(self) raises:
        _ = self._server.close()

    def ref(self) -> Self:
        _ = self._server.ref()
        return self

    def unref(self) -> Self:
        _ = self._server.unref()
        return self

    def listening(self) -> Bool:
        return self._server.listening()


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


def request(
    url: String, callback: Optional[ResponseCallback] = None
) raises -> ClientRequest:
    return request_for_scheme(url, "https:", callback)


def request(
    options: RequestOptions, callback: Optional[ResponseCallback] = None
) raises -> ClientRequest:
    return request_for_scheme(options, "https:", callback)


def get(
    url: String, callback: Optional[ResponseCallback] = None
) raises -> ClientRequest:
    return request(url, callback).end()


def get(
    options: RequestOptions, callback: Optional[ResponseCallback] = None
) raises -> ClientRequest:
    return request(options, callback).end()
