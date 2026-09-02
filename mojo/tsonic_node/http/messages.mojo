from std.collections import List
from std.memory import ArcPointer

from ..buffer import Buffer
from .transport import close_socket, send_buffer, send_string


struct IncomingMessage(ImplicitlyCopyable):
    var method: String
    var url: String
    var _body: Buffer

    def __init__(
        out self,
        var method: String,
        var url: String,
        body: Buffer,
    ):
        self.method = method^
        self.url = url^
        self._body = body

    def read_all(self) raises -> String:
        return self._body.to_string()

    def read_all_buffer(self) -> Buffer:
        return self._body


@fieldwise_init
struct ResponseState:
    var descriptor: Int32
    var status_code: Int32
    var headers: List[Tuple[String, String]]
    var body: List[Byte]
    var finished: Bool


struct ServerResponse(ImplicitlyCopyable):
    var _state: ArcPointer[ResponseState]

    def __init__(out self, descriptor: Int32):
        self._state = ArcPointer(
            ResponseState(
                descriptor,
                Int32(200),
                List[Tuple[String, String]](),
                List[Byte](),
                False,
            )
        )

    def status_code(self) -> Int32:
        return self._state[].status_code

    def set_status_code(self, value: Int32):
        self._state[].status_code = value

    def set_header(self, name: String, value: String) raises:
        if self._state[].finished:
            raise Error("Response headers have already been sent")
        var normalized = name.lower()
        for index in range(len(self._state[].headers)):
            if self._state[].headers[index][0].lower() == normalized:
                self._state[].headers[index] = (name, value)
                return
        self._state[].headers.append((name, value))

    def write_head(self, status_code: Int32, status_message: String) raises:
        self.set_status_code(status_code)

    def write_buffer(self, value: Buffer) raises -> Bool:
        self._append(value.copy_bytes())
        return True

    def end_empty(self) raises:
        self._finish(Buffer())

    def end_string(self, value: String) raises:
        self._finish(Buffer.from_string(value))

    def end_buffer(self, value: Buffer) raises:
        self._finish(value)

    def is_finished(self) -> Bool:
        return self._state[].finished

    def _append(self, bytes: List[Byte]) raises:
        if self._state[].finished:
            raise Error("Response has already ended")
        if len(self._state[].body) + len(bytes) > 64 * 1024 * 1024:
            raise Error("HTTP response body exceeds the finite runtime limit")
        for byte in bytes:
            self._state[].body.append(byte)

    def _finish(self, value: Buffer) raises:
        self._append(value.copy_bytes())
        var status = self._state[].status_code
        if status < 100 or status > 999:
            raise Error("HTTP status code must be between 100 and 999")
        var head = (
            "HTTP/1.1 "
            + String(status)
            + " "
            + _status_message(status)
            + "\r\n"
        )
        var has_length = False
        for header in self._state[].headers:
            head += header[0] + ": " + header[1] + "\r\n"
            if header[0].lower() == "content-length":
                has_length = True
        if not has_length:
            head += (
                "Content-Length: " + String(len(self._state[].body)) + "\r\n"
            )
        head += "Connection: close\r\n\r\n"
        send_string(self._state[].descriptor, head)
        send_buffer(self._state[].descriptor, self._state[].body)
        close_socket(self._state[].descriptor)
        self._state[].descriptor = -1
        self._state[].finished = True


def _status_message(status: Int32) -> String:
    if status == 200:
        return "OK"
    if status == 201:
        return "Created"
    if status == 204:
        return "No Content"
    if status == 301:
        return "Moved Permanently"
    if status == 302:
        return "Found"
    if status == 304:
        return "Not Modified"
    if status == 400:
        return "Bad Request"
    if status == 404:
        return "Not Found"
    if status == 405:
        return "Method Not Allowed"
    if status == 500:
        return "Internal Server Error"
    return "Status"
