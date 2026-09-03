from std.memory import ArcPointer
from tsonic_js import JsString
from tsonic_runtime import RaisingCallable

from .stream import Readable, Writable


comptime QuestionCallback = RaisingCallable[Tuple[String], NoneType]


struct ReadLineOptions(Copyable):
    var input: Readable
    var output: Optional[Writable]
    var terminal: Optional[Bool]
    var prompt: Optional[String]

    def __init__(out self):
        self.input = Readable()
        self.output = None
        self.terminal = None
        self.prompt = None


@fieldwise_init
struct _InterfaceState:
    var input: Readable
    var output: Optional[Writable]
    var prompt: String
    var line: String
    var cursor: Int
    var terminal: Bool
    var paused: Bool
    var closed: Bool


struct Interface(ImplicitlyCopyable):
    var _state: ArcPointer[_InterfaceState]

    def __init__(out self, options: ReadLineOptions):
        self._state = ArcPointer(
            _InterfaceState(
                options.input,
                options.output,
                options.prompt.value() if options.prompt else "> ",
                "",
                0,
                options.terminal.value() if options.terminal else False,
                False,
                False,
            )
        )

    def question(mut self, query: String, callback: QuestionCallback) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        self.write(query)
        var answer = self._read_line()
        callback.call((answer,))

    def write(mut self, text: String) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        if self._state[].output:
            _ = self._state[].output.value().write_string(text)
        self._state[].line += text
        self._state[].cursor = len(JsString(self._state[].line))

    def pause(mut self) -> Self:
        self._state[].paused = True
        return self

    def resume(mut self) -> Self:
        self._state[].paused = False
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def close(mut self):
        self._state[].closed = True

    def set_prompt(mut self, value: String):
        self._state[].prompt = value

    def get_prompt(self) -> String:
        return self._state[].prompt

    def prompt(mut self) raises:
        self.write(self._state[].prompt)

    def line(self) -> String:
        return self._state[].line

    def cursor(self) -> Float64:
        return Float64(self._state[].cursor)

    def terminal(self) -> Bool:
        return self._state[].terminal

    def _read_line(mut self) raises -> String:
        var result = String()
        while True:
            var chunk = self._state[].input.read()
            if not chunk:
                break
            var text = chunk.value().to_string()
            var newline = text.find("\n")
            if newline:
                result += String(text[byte = : newline.value()])
                break
            result += text
        if result.endswith("\r"):
            var without_carriage_return = String(
                result[byte = : result.byte_length() - 1]
            )
            result = without_carriage_return^
        self._state[].line = result
        self._state[].cursor = len(JsString(result))
        return result


def create_interface(options: ReadLineOptions) -> Interface:
    return Interface(options)
