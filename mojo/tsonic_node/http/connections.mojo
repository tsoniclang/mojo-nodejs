from std.collections import List
from tsonic_runtime import GlobalCell, RaisingCallable
from .messages import IncomingMessage, ServerResponse
from .parsing import RequestParser
from .transport import HttpTransport

comptime RequestHandler = RaisingCallable[
    Tuple[IncomingMessage, ServerResponse], NoneType
]
comptime MAX_PENDING = 1 << 20


@fieldwise_init
struct _Request(ImplicitlyCopyable):
    var transport: HttpTransport
    var parser: RequestParser
    var handler: RequestHandler


def _initial_requests() -> List[_Request]:
    return List[_Request]()


def _initial_responses() -> List[ServerResponse]:
    return List[ServerResponse]()


comptime _requests = GlobalCell[
    "tsonic.node.http.server.requests", _initial_requests
]()
comptime _responses = GlobalCell[
    "tsonic.node.http.server.responses", _initial_responses
]()


def accept_connection(transport: HttpTransport, handler: RequestHandler) raises:
    if len(_requests.get()[]) + len(_responses.get()[]) >= MAX_PENDING:
        transport.close()
        raise Error("Pending HTTP connections exceed the finite runtime limit")
    _requests.get()[].append(_Request(transport, RequestParser(), handler))


def has_pending_connections() -> Bool:
    return len(_requests.get()[]) != 0 or len(_responses.get()[]) != 0


def poll_connections() raises -> Bool:
    var did_work = False
    var requests = List[_Request]()
    swap(requests, _requests.get()[])
    var bytes = List[Byte](capacity=65536)
    if len(requests) != 0:
        for _ in range(65536):
            bytes.append(0)
    for index in range(len(requests)):
        var request = requests[index]
        var complete = False
        try:
            var count = request.transport.read_into(bytes)
            if count == -2:
                _requests.get()[].append(request)
                continue
            if count == 0:
                request.transport.close()
                did_work = True
                continue
            complete = request.parser.feed(bytes, count)
            did_work = True
        except:
            request.transport.close()
            did_work = True
            continue
        if not complete:
            _requests.get()[].append(request)
            continue
        var response: Optional[ServerResponse] = None
        try:
            var message = request.parser.message()
            response = ServerResponse(
                request.transport, message.method == "HEAD"
            )
            request.handler.call((message, response.value()))
            if not response.value().is_drained():
                _responses.get()[].append(response.value())
        except error:
            request.transport.close()
            for remaining in range(index + 1, len(requests)):
                _requests.get()[].append(requests[remaining])
            raise error
    var responses = List[ServerResponse]()
    swap(responses, _responses.get()[])
    for response in responses:
        try:
            var progress = response.poll()
            did_work = did_work or progress
            if not response.is_drained():
                _responses.get()[].append(response)
        except:
            response.destroy()
            did_work = True
    return did_work
