from std.collections import List
from std.memory import ArcPointer

from ..buffer import Buffer
from .transport import HttpTransport
from .client_options import check_token


@fieldwise_init
struct _IncomingState:
    var body: Optional[Buffer]


struct IncomingMessage(ImplicitlyCopyable):
    var method: String
    var url: String
    var status_code: Optional[Int32]
    var _state: ArcPointer[_IncomingState]

    def __init__(
        out self,
        var method: String,
        var url: String,
        body: Buffer,
        status_code: Optional[Int32] = None,
    ):
        self.method = method^
        self.url = url^
        self.status_code = status_code
        self._state = ArcPointer(_IncomingState(Optional(body)))

    def read(self) -> Optional[Buffer]:
        var body = self._state[].body
        self._state[].body = None
        return body

    def read_all(self) raises -> String:
        return self.read_all_buffer().to_string()

    def read_all_buffer(self) -> Buffer:
        var body = self.read()
        return body.value() if body else Buffer()


@fieldwise_init
struct ResponseState:
    var transport: HttpTransport
    var status_code: Int32
    var headers: List[Tuple[String, String]]
    var body: List[Byte]
    var finished: Bool
    var output: List[Byte]
    var offset: Int
    var end_sent: Bool
    var head_request: Bool
    var status_message: Optional[String]


struct ServerResponse(ImplicitlyCopyable):
    var _state: ArcPointer[ResponseState]

    def __init__(
        out self, transport: HttpTransport, head_request: Bool = False
    ):
        self._state = ArcPointer(
            ResponseState(
                transport,
                Int32(200),
                List[Tuple[String, String]](),
                List[Byte](),
                False,
                List[Byte](),
                0,
                False,
                head_request,
                None,
            )
        )

    def status_code(self) -> Int32:
        return self._state[].status_code

    def set_status_code(self, value: Int32):
        self._state[].status_code = value

    def set_header(self, name: String, value: String) raises:
        if self._state[].finished:
            raise Error("Response headers have already been sent")
        check_token(name, "response header name")
        _check_header_value(value)
        var normalized = name.lower()
        for index in range(len(self._state[].headers)):
            if self._state[].headers[index][0].lower() == normalized:
                self._state[].headers[index] = (name, value)
                return
        self._state[].headers.append((name, value))

    def write_head(self, status_code: Int32, status_message: String) raises:
        if self._state[].finished:
            raise Error("Response headers have already been sent")
        _check_header_value(status_message)
        self.set_status_code(status_code)
        self._state[].status_message = status_message

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

    def is_drained(self) -> Bool:
        return self._state[].transport.closed()

    def destroy(self):
        self._state[].transport.close()
        self._state[].body = List[Byte]()
        self._state[].output = List[Byte]()
        self._state[].finished = True

    def poll(self) raises -> Bool:
        if not self._state[].finished or self.is_drained():
            return False
        try:
            var written = self._state[].transport.write_some(
                self._state[].output, self._state[].offset
            )
            self._state[].offset += written
            if (
                self._state[].offset == len(self._state[].output)
                and not self._state[].end_sent
            ):
                self._state[].transport.end()
                self._state[].end_sent = True
                self._state[].output = List[Byte]()
                self._state[].offset = 0
            return written != 0
        except error:
            self.destroy()
            raise error

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
            + (
                self._state[]
                .status_message.value() if self._state[]
                .status_message else _status_message(status)
            )
            + "\r\n"
        )
        var has_length = False
        var chunked = False
        var no_body = (
            self._state[].head_request
            or status < 200
            or status == 204
            or status == 304
        )
        for header in self._state[].headers:
            var name = header[0].lower()
            if name == "connection":
                continue
            if name == "transfer-encoding":
                if header[1].strip().lower() != "chunked":
                    raise Error("HTTP response transfer coding must be chunked")
                chunked = True
                if status < 200 or status == 204 or status == 304:
                    continue
            if name == "content-length" and (status < 200 or status == 204):
                continue
            if (
                name == "content-length"
                and not no_body
                and Int(header[1]) != len(self._state[].body)
            ):
                raise Error("Response Content-Length does not match its body")
            head += header[0] + ": " + header[1] + "\r\n"
            if header[0].lower() == "content-length":
                has_length = True
        if has_length and chunked:
            raise Error(
                "Response cannot combine Content-Length and Transfer-Encoding"
            )
        if (
            not has_length
            and not chunked
            and not (status < 200 or status == 204 or status == 304)
        ):
            head += (
                "Content-Length: " + String(len(self._state[].body)) + "\r\n"
            )
        head += "Connection: close\r\n\r\n"
        var output = List[Byte](
            capacity=head.byte_length()
            + (0 if no_body else len(self._state[].body))
        )
        for byte in head.as_bytes():
            output.append(byte)
        if not no_body:
            if chunked and len(self._state[].body) != 0:
                var prefix = _chunk_size(len(self._state[].body)) + "\r\n"
                for byte in prefix.as_bytes():
                    output.append(byte)
            for byte in self._state[].body:
                output.append(byte)
            if chunked:
                var suffix = (
                    "\r\n0\r\n\r\n" if len(self._state[].body)
                    != 0 else "0\r\n\r\n"
                )
                for byte in suffix.as_bytes():
                    output.append(byte)
        self._state[].output = output^
        self._state[].body = List[Byte]()
        self._state[].finished = True
        _ = self.poll()


def _check_header_value(value: String) raises:
    for byte in value.as_bytes():
        if (byte < 32 and byte != 9) or byte == 127:
            raise Error(
                "HTTP response value contains a prohibited control character"
            )


def _chunk_size(var value: Int) -> String:
    comptime digits = "0123456789abcdef"
    var text = String()
    while value != 0:
        text = String(digits[byte=value & 15]) + text
        value >>= 4
    return text if text else "0"


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
