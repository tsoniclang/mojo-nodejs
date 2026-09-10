from std.collections import Deque
from std.time import monotonic


struct LineBuffer(Movable):
    var _complete: Deque[String]
    var current: String
    var _bytes: Int
    var _carriage_return: Optional[Int]
    var _finished: Bool

    def __init__(out self):
        self._complete = Deque[String]()
        self.current = ""
        self._bytes = 0
        self._carriage_return = None
        self._finished = False

    def feed(mut self, text: String) raises:
        if self._finished:
            raise Error("Cannot append line input after EOF")
        var bytes = text.as_bytes()
        var start = 0
        var now = Int(monotonic())
        for index in range(len(bytes)):
            var byte = bytes[index]
            if byte != 10 and byte != 13:
                self._carriage_return = None
                continue
            self._append(String(text[byte=start:index]))
            start = index + 1
            if byte == 10 and self._carriage_return and now - self._carriage_return.value() <= 100000000:
                self._carriage_return = None
                continue
            self._emit()
            if byte == 13:
                self._carriage_return = now
            else:
                self._carriage_return = None
        self._append(String(text[byte=start:]))

    def _append(mut self, text: String) raises:
        if text.byte_length() > 16777216 - self.current.byte_length() or text.byte_length() > 67108864 - self._bytes:
            raise Error("Readline input exceeds its retained text budget")
        self.current += text
        self._bytes += text.byte_length()

    def _emit(mut self) raises:
        if len(self._complete) >= 1048576:
            raise Error("Readline input exceeds its pending line budget")
        self._complete.append(self.current^)
        self.current = ""

    def finish(mut self) raises:
        if self._finished:
            return
        if self.current.byte_length() != 0:
            self._emit()
        self._finished = True

    def take(mut self) -> Optional[String]:
        if len(self._complete) == 0:
            return None
        var line = self._complete.popleft()
        self._bytes -= line.byte_length()
        return Optional(line^)

    def clear(mut self):
        self._complete.clear()
        self._bytes = self.current.byte_length()

    def finished(self) -> Bool:
        return self._finished

    def has_lines(self) -> Bool:
        return len(self._complete) != 0

    def cursor(self) -> Int:
        var result = 0
        for point in self.current.codepoints():
            result += 2 if point.to_u32() > 0xFFFF else 1
        return result
