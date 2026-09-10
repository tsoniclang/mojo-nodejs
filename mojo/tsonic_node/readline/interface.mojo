from std.collections import List
from std.ffi import c_int, external_call
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable
from ..buffer import Buffer
from ..stream import Readable, Writable
from ..stream.decoder import StreamDecoder
from ..validation import checked_integer
from .lines import LineBuffer
from .options import ReadLineOptions


comptime QuestionCallback = RaisingCallable[Tuple[String], NoneType]


@fieldwise_init
struct _InterfaceState:
    var input: Readable
    var output: Optional[Writable]
    var prompt: String
    var query: String
    var lines: LineBuffer
    var decoder: StreamDecoder
    var callback: Optional[QuestionCallback]
    var terminal: Bool
    var paused: Bool
    var closed: Bool
    var registered: Bool
    var dispatching: Bool
    var history: List[String]
    var history_size: Int
    var unique_history: Bool


struct Interface(ImplicitlyCopyable):
    var _state: ArcPointer[_InterfaceState]

    def __init__(out self, options: ReadLineOptions) raises:
        var history_size = Int(checked_integer(options.historySize.value(), 1048576, "historySize")) if options.historySize else 30
        self._state = ArcPointer(_InterfaceState(options.input, options.output,
            options.prompt.value() if options.prompt else "> ", "", LineBuffer(), StreamDecoder(), None,
            options.terminal.value() if options.terminal else False, False, False, False, False,
            List[String](), history_size, options.removeHistoryDuplicates.value() if options.removeHistoryDuplicates else False))

    def question(mut self, query: String, callback: QuestionCallback) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        if self._state[].callback:
            self._output(self._state[].query)
            _ = self.resume()
            return
        self._register()
        self._output(query)
        self._state[].query = query
        self._state[].callback = callback
        _ = self.resume()

    def write(mut self, text: String) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        _ = self.resume()
        self._state[].lines.feed(text)
        self._dispatch()

    def _output(self, text: String) raises:
        if self._state[].output:
            _ = self._state[].output.value().write_string(text)

    def pause(mut self) -> Self:
        self._state[].paused = True
        _ = self._state[].input.pause()
        return self

    def resume(mut self) -> Self:
        self._state[].paused = False
        _ = self._state[].input.resume()
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def close(mut self):
        self._state[].closed = True
        self._state[].callback = None
        self._state[].lines.clear()
        _prune_interfaces()

    def set_prompt(mut self, value: String):
        self._state[].prompt = value

    def get_prompt(self) -> String:
        return self._state[].prompt

    def prompt(mut self) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        _ = self.resume()
        self._output(self._state[].prompt)

    def line(self) -> String:
        return self._state[].lines.current

    def cursor(self) -> Float64:
        return Float64(self._state[].lines.cursor())

    def terminal(self) -> Bool:
        return self._state[].terminal

    def _register(self) raises:
        if self._state[].registered:
            return
        _prune_interfaces()
        if len(_interfaces.get()[]) >= 16384:
            raise Error("Pending readline interfaces exceed the finite runtime limit")
        self._state[].registered = True
        _interfaces.get()[].append(self)

    def _history(self, text: String):
        if not self._state[].terminal or self._state[].history_size == 0 or text.byte_length() == 0:
            return
        var history = self._state[].history
        if len(history) and history[0] == text:
            return
        var retained = List[String](capacity=min(self._state[].history_size, len(history) + 1))
        retained.append(text)
        for previous in history:
            if len(retained) == self._state[].history_size:
                break
            if not self._state[].unique_history or previous != text:
                retained.append(previous)
        self._state[].history = retained^

    def _dispatch(mut self) raises:
        if self._state[].dispatching or self._state[].paused or self._state[].closed:
            return
        self._state[].dispatching = True
        try:
            while not self._state[].paused and not self._state[].closed:
                var line = self._state[].lines.take()
                if not line:
                    break
                self._history(line.value())
                if self._state[].callback:
                    var callback = self._state[].callback.value()
                    self._state[].callback = None
                    callback.call((line.value(),))
        finally:
            self._state[].dispatching = False

    def _poll(mut self) raises -> Bool:
        if self._state[].closed or self._state[].paused or self._state[].dispatching or not self._state[].callback:
            return False
        self._dispatch()
        if self._state[].lines.finished():
            self.close()
            return True
        if self._state[].closed or self._state[].paused or not self._state[].callback:
            return True
        var result: Tuple[Bool, Bool]
        try:
            result = self._receive()
        except error:
            self.close()
            raise error^
        self._dispatch()
        if result[1]:
            self.close()
        return result[0]

    def _receive(mut self) raises -> Tuple[Bool, Bool]:
        var worked = self._state[].input.poll_input()
        var chunk = self._state[].input.read()
        if chunk:
            var value = chunk.value()
            var text = value.unsafe_get[String]() if value.isa[String]() else self._state[].decoder.write(value.unsafe_get[Buffer]())
            self._state[].lines.feed(text)
            worked = True
        if self._state[].input.input_ended() and not chunk:
            self._state[].lines.feed(self._state[].decoder.end())
            self._state[].lines.finish()
            return (True, True)
        return (worked, False)


def _initial_interfaces() -> List[Interface]:
    return List[Interface]()


comptime _interfaces = GlobalCell["tsonic.node.readline.interfaces", _initial_interfaces]()


def _prune_interfaces():
    var retained = List[Interface]()
    for interface in _interfaces.get()[]:
        if not interface._state[].closed and interface._state[].callback:
            retained.append(interface)
        else:
            interface._state[].registered = False
    _interfaces.get()[] = retained^


def has_pending_readline() -> Bool:
    _prune_interfaces()
    return len(_interfaces.get()[]) != 0


def poll_readline() raises -> Bool:
    var worked = external_call["tsonic_node_stream_read_poll", c_int]() != 0
    var snapshot = _interfaces.get()[].copy()
    try:
        for interface in snapshot:
            worked = interface._poll() or worked
    finally:
        _prune_interfaces()
    return worked
