from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable
from ..buffer import Buffer
from ..url import URL
from .client_options import RequestOptions, check_token, request_url
from .client_transport import MAX_MESSAGE_BYTES, NativeRequest, poll_transport
from .messages import IncomingMessage

comptime ResponseCallback = RaisingCallable[Tuple[IncomingMessage], NoneType]


struct _ClientState:
    var address: URL
    var options: RequestOptions
    var method: String
    var callback: Optional[ResponseCallback]
    var headers: List[Tuple[String, String]]
    var body: List[Byte]
    var body_present: Bool
    var ended: Bool
    var destroyed: Bool
    var native: Optional[NativeRequest]

    def __init__(out self, address: URL, options: RequestOptions, callback: Optional[ResponseCallback]) raises:
        self.address = address
        self.options = options.copy()
        self.method = options.method.value().upper() if options.method else String("GET")
        check_token(self.method, "method")
        self.callback = callback
        self.headers = List[Tuple[String, String]]()
        self.body = List[Byte]()
        self.body_present = False
        self.ended = False
        self.destroyed = False
        self.native = None


struct ClientRequest(ImplicitlyCopyable):
    var _state: ArcPointer[_ClientState]

    def __init__(out self, address: URL, options: RequestOptions, callback: Optional[ResponseCallback]) raises:
        self._state = ArcPointer(_ClientState(address, options, callback))

    def path(self) raises -> String:
        return self._state[].address.pathname() + self._state[].address.search()

    def method(self) -> String:
        return self._state[].method

    def host(self) raises -> String:
        return self._state[].address.hostname()

    def protocol(self) raises -> String:
        return self._state[].address.protocol()

    def set_header(self, name: String, value: String) raises:
        self._require_open()
        check_token(name, "header name")
        for byte in value.as_bytes():
            if (byte < 32 and byte != 9) or byte == 127:
                raise Error("HTTP header contains a prohibited control character")
        var key = name.lower()
        for index in range(len(self._state[].headers)):
            if self._state[].headers[index][0].lower() == key:
                self._state[].headers[index] = (name, value)
                return
        self._state[].headers.append((name, value))

    def remove_header(self, name: String) raises:
        self._require_open()
        var key = name.lower()
        var retained = List[Tuple[String, String]]()
        for header in self._state[].headers:
            if header[0].lower() != key:
                retained.append(header)
        self._state[].headers = retained^

    def write_buffer(self, value: Buffer) raises -> Bool:
        self._require_open()
        if len(value) > MAX_MESSAGE_BYTES - len(self._state[].body):
            raise Error("HTTP request body exceeds the runtime byte budget")
        self._state[].body_present = True
        for byte in value.copy_bytes():
            self._state[].body.append(byte)
        return True

    def write_string(self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def end(self) raises -> Self:
        if self._state[].destroyed:
            raise Error("Cannot end a destroyed HTTP request")
        if self._state[].ended:
            return self
        var native = NativeRequest(self._state[].address.href(), self._state[].options)
        for header in self._state[].headers:
            native.header(header[0], header[1])
        native.start(self._state[].method, self._state[].body, self._state[].body_present, self._state[].options.timeout)
        self._state[].native = native
        self._state[].ended = True
        self._state[].body = List[Byte]()
        _requests.get()[].append(self)
        return self

    def end_buffer(self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def destroy(self) -> Self:
        self._state[].destroyed = True
        self._state[].callback = None
        self._state[].body = List[Byte]()
        if self._state[].native:
            self._state[].native.value().close()
            self._state[].native = None
        return self

    def _require_open(self) raises:
        if self._state[].ended or self._state[].destroyed:
            raise Error("HTTP request is no longer writable")


def _initial_requests() -> List[ClientRequest]:
    return List[ClientRequest]()


comptime _requests = GlobalCell["tsonic.node.http.client.requests", _initial_requests]()


def has_pending_requests() -> Bool:
    return len(_requests.get()[]) != 0


def poll_requests() raises -> Bool:
    if not has_pending_requests():
        return False
    poll_transport()
    var snapshot = List[ClientRequest]()
    swap(snapshot, _requests.get()[])
    var completed = List[ClientRequest]()
    for request in snapshot:
        if request._state[].destroyed:
            continue
        if request._state[].native.value().complete():
            completed.append(request)
        else:
            _requests.get()[].append(request)
    for index in range(len(completed)):
        var request = completed[index]
        if request._state[].destroyed:
            continue
        var native = request._state[].native.value()
        try:
            native.check_error()
            var response = IncomingMessage("", request._state[].address.href(), native.body(), Optional(native.status()))
            if request._state[].callback:
                request._state[].callback.value().call((response,))
        except error:
            for remaining in range(index + 1, len(completed)):
                _requests.get()[].append(completed[remaining])
            raise error
        finally:
            native.close()
            request._state[].native = None
            request._state[].callback = None
    return len(completed) != 0


def request_for_scheme(url: String, scheme: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    var address = URL(url)
    if address.protocol() != scheme:
        raise Error("Request URL does not match the selected Node module")
    return ClientRequest(address, RequestOptions(), callback)


def request_for_scheme(options: RequestOptions, scheme: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return ClientRequest(request_url(options, scheme), options, callback)


def request(url: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request_for_scheme(url, "http:", callback)


def request(options: RequestOptions, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request_for_scheme(options, "http:", callback)


def get(url: String, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request(url, callback).end()


def get(options: RequestOptions, callback: Optional[ResponseCallback] = None) raises -> ClientRequest:
    return request(options, callback).end()
