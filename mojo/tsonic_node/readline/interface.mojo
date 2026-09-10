from std.collections import List
from std.memory import ArcPointer
from std.memory.arc_pointer import WeakPointer
from tsonic_runtime import GlobalCell, RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from ..internal.callback_queue import Notification
from ..buffer import Buffer
from ..stream import Readable, Writable
from ..stream.decoder import StreamDecoder
from ..stream.chunk import StreamChunk
from ..stream.read_events import DataCallback
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
    var input_data: Optional[DataCallback]
    var input_end: Optional[Notification]
    var input_close: Optional[Notification]


struct Interface(ImplicitlyCopyable):
    var _state: ArcPointer[_InterfaceState]

    def __init__(out self, options: ReadLineOptions) raises:
        var history_size = Int(checked_integer(options.historySize.value(), 1048576, "historySize")) if options.historySize else 30
        self._state = ArcPointer(_InterfaceState(options.input, options.output,
            options.prompt.value() if options.prompt else "> ", "", LineBuffer(), StreamDecoder(), None,
            options.terminal.value() if options.terminal else False, False, False, False, False,
            List[String](), history_size, options.removeHistoryDuplicates.value() if options.removeHistoryDuplicates else False,
            None, None, None))
        self._register()
        try:
            self._subscribe()
        except error:
            self._state[].closed = True
            self._unsubscribe()
            _prune_interfaces()
            raise error^

    def __init__(out self, state: ArcPointer[_InterfaceState]):
        self._state = state

    def _subscribe(self) raises:
        var environment = allocate_callable_environment(
            _InterfaceInput(WeakPointer[_InterfaceState](downgrade=self._state)), destroy_callable_environment[_InterfaceInput],
        )
        var data = DataCallback(environment, _InterfaceInput.data)
        var end = Notification(environment, _InterfaceInput.end)
        var close = Notification(environment, _InterfaceInput.close)
        _ = self._state[].input.once_empty("end", end)
        self._state[].input_end = end
        _ = self._state[].input.once_empty("close", close)
        self._state[].input_close = close
        _ = self._state[].input.on_data("data", data)
        self._state[].input_data = data

    def question(mut self, query: String, callback: QuestionCallback) raises:
        if self._state[].closed:
            raise Error("readline interface is closed")
        if self._state[].callback:
            self._output(self._state[].query)
            _ = self.resume()
            return
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

    def pause(mut self) raises -> Self:
        self._state[].paused = True
        _ = self._state[].input.pause()
        return self

    def resume(mut self) raises -> Self:
        self._state[].paused = False
        _ = self._state[].input.resume()
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def close(mut self) raises:
        if self._state[].closed:
            return
        self._state[].closed = True
        self._state[].callback = None
        self._state[].lines.clear()
        try:
            _ = self._state[].input.pause()
        finally:
            self._unsubscribe()
            _prune_interfaces()

    def _unsubscribe(self) raises:
        if self._state[].input_data:
            _ = self._state[].input.off_data("data", self._state[].input_data.value())
            self._state[].input_data = None
        if self._state[].input_end:
            _ = self._state[].input.off_empty("end", self._state[].input_end.value())
            self._state[].input_end = None
        if self._state[].input_close:
            _ = self._state[].input.off_empty("close", self._state[].input_close.value())
            self._state[].input_close = None

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
        if len(self._state[].history) and self._state[].history[0] == text:
            return
        var retained = List[String](capacity=min(self._state[].history_size, len(self._state[].history) + 1))
        retained.append(text)
        for previous in self._state[].history:
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
        if self._state[].closed or self._state[].paused or self._state[].dispatching:
            return False
        var worked = self._state[].lines.has_lines()
        self._dispatch()
        if self._state[].lines.finished():
            self.close()
            return True
        return worked


@fieldwise_init
struct _InterfaceInput:
    var owner: WeakPointer[_InterfaceState]

    @staticmethod
    def data(context: ErasedCallableContext, var arguments: Tuple[StreamChunk]) raises:
        var input = context.unsafe_bitcast[Self]()
        var state = input[].owner.try_upgrade()
        if not state or state.value()[].closed:
            return
        var interface = Interface(state.value())
        var value = arguments[0].copy()
        var text = value.unsafe_get[String]() if value.isa[String]() else interface._state[].decoder.write(value.unsafe_get[Buffer]())
        interface._state[].lines.feed(text)
        interface._dispatch()

    @staticmethod
    def end(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var input = context.unsafe_bitcast[Self]()
        var state = input[].owner.try_upgrade()
        if not state or state.value()[].closed:
            return
        var interface = Interface(state.value())
        interface._state[].lines.feed(interface._state[].decoder.end())
        interface._state[].lines.finish()
        _ = interface._poll()

    @staticmethod
    def close(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var input = context.unsafe_bitcast[Self]()
        var state = input[].owner.try_upgrade()
        if state:
            var interface = Interface(state.value())
            if not interface._state[].lines.finished():
                interface.close()


def _initial_interfaces() -> List[Interface]:
    return List[Interface]()


comptime _interfaces = GlobalCell["tsonic.node.readline.interfaces", _initial_interfaces]()


def _prune_interfaces():
    var retained = List[Interface]()
    for interface in _interfaces.get()[]:
        if not interface._state[].closed:
            retained.append(interface)
        else:
            interface._state[].registered = False
    _interfaces.get()[] = retained^


def has_pending_readline() -> Bool:
    _prune_interfaces()
    return len(_interfaces.get()[]) != 0


def poll_readline() raises -> Bool:
    var worked = False
    var snapshot = _interfaces.get()[].copy()
    try:
        for interface in snapshot:
            worked = interface._poll() or worked
    finally:
        _prune_interfaces()
    return worked
