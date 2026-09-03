from std.collections import List
from std.ffi import c_int, c_size_t, c_ssize_t, c_ulong, external_call
from std.memory import ArcPointer
from std.sys._libc import close
from tsonic_runtime import GlobalCell, RaisingCallable

from ..buffer import Buffer
from .messages import IncomingMessage, ServerResponse
from .parsing import (
    find_header_end,
    parse_request_bytes,
    request_content_length,
)


comptime RequestArguments = Tuple[IncomingMessage, ServerResponse]
comptime RequestHandler = RaisingCallable[RequestArguments, NoneType]
comptime ListenCallback = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct ServerState:
    var descriptor: Int32
    var handler: RequestHandler
    var listening_callback: Optional[ListenCallback]
    var listening_callback_pending: Bool
    var active: Bool


struct Server(ImplicitlyCopyable):
    var _state: ArcPointer[ServerState]

    def __init__(out self, handler: RequestHandler):
        self._state = ArcPointer(ServerState(-1, handler, None, False, False))

    def listen_default_host(
        self,
        port: Int32,
        callback: ListenCallback,
    ) raises -> Self:
        return self.listen(port, "0.0.0.0", callback)

    def listen(
        self,
        port: Int32,
        host: String,
        callback: ListenCallback,
    ) raises -> Self:
        if self._state[].active:
            raise Error("HTTP server is already listening")
        var descriptor = _listen_socket(port, host)
        self._state[].descriptor = descriptor
        self._state[].listening_callback = Optional(callback)
        self._state[].listening_callback_pending = True
        self._state[].active = True
        if len(_servers.get()[]) >= _max_servers:
            _ = close(descriptor)
            self._state[].active = False
            raise Error("Active HTTP servers exceed the finite runtime limit")
        _servers.get()[].append(self)
        return self

    def close(self):
        if self._state[].descriptor >= 0:
            _ = close(self._state[].descriptor)
        self._state[].descriptor = -1
        self._state[].active = False


def create_server(handler: RequestHandler) -> Server:
    return Server(handler)


def _initial_servers() -> List[Server]:
    return List[Server]()


def _initial_responses() -> List[ServerResponse]:
    return List[ServerResponse]()


comptime _servers = GlobalCell["tsonic.node.http.servers", _initial_servers]()
comptime _responses = GlobalCell[
    "tsonic.node.http.responses", _initial_responses
]()
comptime _max_servers = 1024
comptime _max_pending_responses = 1 << 20


def has_active_servers() -> Bool:
    for index in range(len(_servers.get()[])):
        if _servers.get()[][index]._state[].active:
            return True
    return len(_responses.get()[]) > 0


def poll_servers() raises -> Bool:
    var did_work = False
    for index in range(len(_servers.get()[])):
        var server = _servers.get()[][index]
        if not server._state[].active:
            continue
        if server._state[].listening_callback_pending:
            server._state[].listening_callback_pending = False
            if server._state[].listening_callback:
                server._state[].listening_callback.value().call(())
            did_work = True
        if _socket_readable(server._state[].descriptor):
            _accept_request(server)
            did_work = True
    var retained = List[ServerResponse](capacity=len(_responses.get()[]))
    for index in range(len(_responses.get()[])):
        var response = _responses.get()[][index]
        if not response.is_finished():
            retained.append(response)
    _responses.get()[] = retained^
    return did_work


def _accept_request(server: Server) raises:
    var peer_address = Array[UInt8, 128](fill=0)
    var peer_address_length = UInt32(128)
    var descriptor = external_call["accept", c_int](
        server._state[].descriptor,
        peer_address.unsafe_ptr(),
        Pointer(to=peer_address_length),
    )
    if descriptor < 0:
        return
    try:
        var request = _read_request(descriptor)
        var response = ServerResponse(descriptor)
        server._state[].handler.call((request, response))
        if not response.is_finished():
            if len(_responses.get()[]) >= _max_pending_responses:
                response.end_empty()
                raise Error(
                    "Pending HTTP responses exceed the finite runtime limit"
                )
            _responses.get()[].append(response)
    except error:
        _ = close(descriptor)
        raise error


def _read_request(descriptor: Int32) raises -> IncomingMessage:
    var bytes = List[Byte]()
    var header_end = -1
    while header_end < 0:
        _read_chunk(descriptor, bytes)
        header_end = find_header_end(bytes)
        if len(bytes) > 64 * 1024:
            raise Error("HTTP request headers exceed the finite runtime limit")
    var content_length = request_content_length(bytes, header_end)
    var body_start = header_end + 4
    while len(bytes) - body_start < content_length:
        _read_chunk(descriptor, bytes)
    return parse_request_bytes(bytes)


def _read_chunk(descriptor: Int32, mut bytes: List[Byte]) raises:
    var buffer = Array[Byte, 4096](fill=0)
    var count = external_call["recv", c_ssize_t](
        descriptor, buffer.unsafe_ptr(), c_size_t(4096), c_int(0)
    )
    if count <= 0:
        raise Error("HTTP request ended before it was complete")
    for index in range(count):
        bytes.append(buffer[index])


def _socket_readable(descriptor: Int32) raises -> Bool:
    var poll_data = Array[Int32, 2](fill=0)
    poll_data[0] = descriptor
    poll_data[1] = 1
    var result = external_call["poll", c_int](
        poll_data.unsafe_ptr(), c_ulong(1), c_int(0)
    )
    if result < 0:
        raise Error("Unable to poll HTTP server socket")
    return result > 0 and ((poll_data[1] >> 16) & 1) == 1


def _listen_socket(port: Int32, host: String) raises -> Int32:
    if port < 0 or port > 65535:
        raise Error("HTTP server port must be between 0 and 65535")
    var descriptor = external_call["socket", c_int](
        c_int(2), c_int(1), c_int(0)
    )
    if descriptor < 0:
        raise Error("Unable to create HTTP server socket")
    var address = Array[UInt8, 16](fill=0)
    address[0] = 2
    address[2] = UInt8(Int(port) >> 8)
    address[3] = UInt8(Int(port) & 255)
    _write_ipv4_address(address, host)
    if (
        external_call["bind", c_int](
            descriptor, address.unsafe_ptr(), c_int(16)
        )
        != 0
    ):
        _ = close(descriptor)
        raise Error("Unable to bind HTTP server socket")
    if external_call["listen", c_int](descriptor, c_int(128)) != 0:
        _ = close(descriptor)
        raise Error("Unable to listen on HTTP server socket")
    return descriptor


def _write_ipv4_address(mut address: Array[UInt8, 16], host: String) raises:
    if host == "0.0.0.0":
        return
    if host == "localhost" or host == "127.0.0.1":
        address[4] = 127
        address[7] = 1
        return
    var octets = host.split(".")
    if len(octets) != 4:
        raise Error("HTTP server host must be an IPv4 address or localhost")
    for index in range(4):
        var value = Int(String(octets[index]))
        if value < 0 or value > 255:
            raise Error("HTTP server host contains an invalid IPv4 octet")
        address[4 + index] = UInt8(value)
