from std.collections import List
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, error_new
from ..internal.callback_queue import Notification
from ..buffer import Buffer
from ..buffer.codec import encoding_name
from ..http import ServerResponse
from .descriptor import StreamDescriptor
from .read_buffer import ReadBuffer
from .chunk import StreamChunk
from .read_state import _ReadableState
from .read_size import requested_read_size, increased_read_threshold
from .writable import Writable
from .pipe_sink import PipeSink, PipeSubscription
from .read_events import ReadEvents, DataCallback, ReadErrorCallback
from .completion import stream_completions


struct Readable(ImplicitlyCopyable):
    var _state: ArcPointer[_ReadableState]

    def __init__(out self):
        self._state = ArcPointer(
            _ReadableState(
                None,
                ReadBuffer(),
                False,
                False,
                False,
                False,
                False,
                "",
                4096,
                None,
                None,
                0,
                False,
                False,
                None,
                List[PipeSubscription](),
                ReadEvents(),
                False,
                False,
                False,
                False,
                False,
            )
        )

    def __init__(out self, descriptor: Int32):
        self = Self()
        self._state[].descriptor = StreamDescriptor(descriptor)

    def __init__(out self, state: ArcPointer[_ReadableState]):
        self._state = state

    def __init__(
        out self,
        descriptor: StreamDescriptor,
        path: String,
        chunk_size: Int,
        start: Optional[Int64],
        end: Optional[Int64],
        auto_close: Bool,
    ):
        self._state = ArcPointer(
            _ReadableState(
                Optional(descriptor),
                ReadBuffer(),
                False,
                False,
                False,
                False,
                False,
                path,
                chunk_size,
                start,
                end,
                0,
                auto_close,
                False,
                None,
                List[PipeSubscription](),
                ReadEvents(),
                False,
                False,
                False,
                False,
                False,
            )
        )

    def append(mut self, value: Buffer) raises:
        if self._state[].closed or self._state[].failed or self._state[].eof:
            raise Error("Cannot append to a closed or ended readable stream")
        self._state[].events.prepare()
        try:
            self._state[].chunks.append(value)
            self._state[].readable_pending = True
        except error:
            self._abort(String(error))

    def read(mut self) raises -> Optional[StreamChunk]:
        return self.read_sized(None)

    def read_sized(
        mut self, requested: Optional[Float64]
    ) raises -> Optional[StreamChunk]:
        var value = self._read_sized(requested)
        if value:
            _ = self._state[].events.state[].data.emit((value.value().copy(),))
        return value^

    def _read_sized(
        mut self, requested: Optional[Float64]
    ) raises -> Optional[StreamChunk]:
        var selected = requested_read_size(requested)
        if selected:
            self._state[].chunk_size = increased_read_threshold(
                selected.value(), self._state[].chunk_size
            )
        if self._state[].closed or self._state[].failed:
            return None
        self._state[].events.prepare()
        self._state[].readable_pending = False
        var desired = self._state[].chunk_size
        if selected:
            desired = Int(selected.value()) if selected.value() > 0 else 0
        if (
            len(self._state[].chunks) < desired
            or len(self._state[].chunks) == 0
        ):
            var minimum = desired if selected else 1
            self._fill(1 if minimum > 0 else 0)
            while (
                self._state[].descriptor
                and not self._state[].eof
                and len(self._state[].chunks) < minimum
            ):
                var previous_bytes = self._state[].bytes_read
                self._fill(1)
                if previous_bytes == self._state[].bytes_read:
                    break
        if self._state[].failed:
            return None
        if len(self._state[].chunks) == 0 and self._state[].eof:
            self._state[].ended = True
            self._state[].events.end()
            if self._state[].auto_close:
                self.close()
            return None
        if selected:
            if selected.value() <= 0:
                return None
            if len(self._state[].chunks) < desired and not self._state[].eof:
                return None
            return self._state[].chunks.take(
                min(desired, len(self._state[].chunks))
            )
        return self._state[].chunks.take(len(self._state[].chunks))

    def set_encoding(mut self, name: String) raises -> Self:
        var selected = encoding_name(name)
        self._state[].events.prepare()
        try:
            self._state[].chunks.set_encoding(selected)
        except error:
            self._abort(String(error))
        return self

    def _fill(mut self, minimum: Int = 0) raises:
        try:
            if self._state[].asynchronous:
                self._poll_descriptor(minimum)
            else:
                self._read_descriptor(minimum)
        except error:
            self._abort(String(error))

    def _abort(self, message: String) raises:
        self._state[].events.prepare()
        self._state[].failed = True
        self._state[].native_read = None
        self._state[].chunks.clear()
        if self._state[].auto_close:
            self._state[].descriptor = None
        self._state[].events.fail(error_new(message))
        self._state[].events.close()

    def poll_input(mut self) raises -> Bool:
        self._state[].asynchronous = True
        if self._state[].closed or self._state[].failed:
            return False
        var before = self._state[].bytes_read
        var eof = self._state[].eof
        var pending = Bool(self._state[].native_read)
        if len(self._state[].chunks) == 0 or pending:
            self._fill(1)
        return (
            before != self._state[].bytes_read
            or eof != self._state[].eof
            or pending != Bool(self._state[].native_read)
        )

    def input_ended(self) -> Bool:
        return self._state[].eof or self._state[].closed or self._state[].failed

    def _poll_descriptor(mut self, minimum: Int) raises:
        if self._state[].native_read:
            if not self._state[].native_read.value().ready():
                return
            var result = self._state[].native_read.value().result()
            self._state[].native_read = None
            self._accept_read(result)
            return
        var size = min(1048576, self._request_size(minimum))
        if size > 0:
            self._state[].native_read = (
                self._state[]
                .descriptor.value()
                .begin_read(size, self._state[].position)
            )

    def _request_size(mut self, minimum: Int) raises -> Int:
        if self._state[].eof or not self._state[].descriptor:
            return 0
        var size = max(minimum, self._state[].chunk_size)
        if self._state[].end:
            var position = (
                self._state[]
                .position.value() if self._state[]
                .position else self._state[]
                .bytes_read
            )
            size = Int(
                min(
                    Int64(size),
                    max(Int64(0), self._state[].end.value() - position + 1),
                )
            )
            if position > self._state[].end.value():
                self._state[].eof = True
                self._state[].chunks.finish()
        return size

    def _read_descriptor(mut self, minimum: Int) raises:
        var size = self._request_size(minimum)
        if size == 0:
            return
        var result = (
            self._state[].descriptor.value().read(size, self._state[].position)
        )
        self._accept_read(result)

    def _accept_read(mut self, result: Optional[Buffer]) raises:
        if not result:
            self._state[].eof = True
            self._state[].chunks.finish()
            self._state[].readable_pending = True
            return
        var count = Int64(len(result.value()))
        self._state[].bytes_read += count
        if self._state[].position:
            self._state[].position = self._state[].position.value() + count
        self._state[].chunks.append(result.value())
        self._state[].readable_pending = True

    def close(self) raises:
        if self._state[].closed:
            return
        self._state[].events.prepare()
        self._state[].closed = True
        self._state[].native_read = None
        self._state[].chunks.clear()
        try:
            if self._state[].descriptor:
                self._state[].descriptor.value().close()
        except error:
            self._state[].events.fail(error_new(String(error)))
        finally:
            self._state[].events.close()

    def readable(self) -> Bool:
        return (
            not self._state[].ended
            and not self._state[].closed
            and not self._state[].failed
        )

    def readable_ended(self) -> Bool:
        return self._state[].events.state[].ended

    def path(self) -> String:
        return self._state[].path

    def bytes_read(self) -> Float64:
        return Float64(self._state[].bytes_read)

    def pipe_to(mut self, destination: Writable) raises -> Writable:
        self._add_pipe(PipeSink(destination))
        return destination

    def pipe_to_response(
        mut self, destination: ServerResponse
    ) raises -> ServerResponse:
        self._add_pipe(PipeSink(destination))
        return destination

    def _add_pipe(mut self, sink: PipeSink) raises:
        if self._state[].events.state[].ended:
            var subscription = PipeSubscription(sink)
            stream_completions.get()[].push(subscription.end)
            return
        if self._state[].closed or self._state[].failed:
            return
        if len(self._state[].pipes) >= 1024:
            raise Error(
                "Readable pipe destinations exceed the finite runtime limit"
            )
        self._activate()
        var subscription = PipeSubscription(sink)
        self._state[].events.state[].data.add(subscription.data)
        try:
            self._state[].events.notifications("end").add(
                subscription.end, True
            )
        except error:
            self._state[].events.state[].data.remove(subscription.data)
            raise error^
        self._state[].pipes.append(subscription)
        _ = self.resume()

    def _poll(mut self) raises -> Bool:
        if self._state[].polling:
            return False
        if (
            self._state[].failed
            or self._state[].closed
            and not self._state[].ended
        ):
            return self._prune_sinks(True)
        self._state[].polling = True
        try:
            return self._poll_ready()
        finally:
            self._state[].polling = False

    def _prune_sinks(self, all_sinks: Bool = False) -> Bool:
        var previous = len(self._state[].pipes)
        if previous == 0:
            return False
        var terminal = (
            all_sinks
            or self._state[].failed
            or self._state[].events.state[].ended
            or self._state[].events.state[].closed
            or self._state[].closed
            and not self._state[].ended
        )
        var retained = List[PipeSubscription]()
        for subscription in self._state[].pipes:
            if not terminal and subscription.sink.writable():
                retained.append(subscription)
            else:
                self._state[].events.state[].data.remove(subscription.data)
                var endings = (
                    self._state[].events.state[].notifications.get("end")
                )
                if endings:
                    endings.value().remove(subscription.end)
        self._state[].pipes = retained^
        if (
            previous
            and not self._state[].pipes
            and not self._state[].events.state[].data.has_listeners()
        ):
            self._state[].flowing = False
        return previous != len(self._state[].pipes)

    def _poll_ready(mut self) raises -> Bool:
        var worked = self._prune_sinks()
        var blocked = False
        for subscription in self._state[].pipes:
            blocked = not subscription.sink.ready() or blocked
        if self._state[].resume_pending:
            self._state[].resume_pending = False
            self._state[].events.emit("resume")
            worked = True
        if (
            blocked
            or self._state[].ended
            or self._state[].closed
            or self._state[].failed
        ):
            return worked
        var readable_listener = self._state[].events.has("readable")
        if not self._state[].flowing and not readable_listener:
            if self._state[].native_read:
                self._fill(0)
                worked = not self._state[].native_read or worked
            return worked
        if self._state[].paused and not readable_listener:
            if self._state[].native_read:
                self._fill(0)
                worked = not self._state[].native_read or worked
            return worked
        worked = self.poll_input() or worked
        if readable_listener and self._state[].readable_pending:
            self._state[].readable_pending = False
            self._state[].events.emit("readable")
            worked = True
        if (
            not self._state[].paused
            and self._state[].flowing
            and not readable_listener
        ):
            var value = self.read()
            worked = Bool(value) or self._state[].ended or worked
        return worked

    def pause(mut self) raises -> Self:
        var changed = not self._state[].paused
        self._state[].paused = True
        self._state[].flowing = False
        if changed:
            self._state[].events.emit("pause")
        return self

    def resume(mut self) raises -> Self:
        self._activate()
        if self._state[].paused or not self._state[].flowing:
            self._state[].resume_pending = True
        self._state[].paused = False
        self._state[].flowing = True
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def _activate(self) raises:
        self._state[].events.prepare()
        if not self._state[].registered:
            _prune_readables()
            if len(_readable_sources.get()[]) >= 16384:
                raise Error(
                    "Active readable streams exceed the finite runtime limit"
                )
            _readable_sources.get()[].append(self._state)
            self._state[].registered = True
        self._state[].asynchronous = True

    def on_data(mut self, event: String, callback: DataCallback) raises -> Self:
        return self._add_data(event, callback, False)

    def once_data(
        mut self, event: String, callback: DataCallback
    ) raises -> Self:
        return self._add_data(event, callback, True)

    def _add_data(
        mut self, event: String, callback: DataCallback, once: Bool
    ) raises -> Self:
        if event != "data":
            raise Error("Unsupported readable data event: ", event)
        self._activate()
        self._state[].events.state[].data.add(callback, once)
        if not self._state[].paused:
            _ = self.resume()
        return self

    def off_data(
        mut self, event: String, callback: DataCallback
    ) raises -> Self:
        if event != "data":
            raise Error("Unsupported readable data event: ", event)
        self._state[].events.state[].data.remove(callback)
        return self

    def on_empty(
        mut self, event: String, callback: Notification
    ) raises -> Self:
        return self._add_empty(event, callback, False)

    def once_empty(
        mut self, event: String, callback: Notification
    ) raises -> Self:
        return self._add_empty(event, callback, True)

    def _add_empty(
        mut self, event: String, callback: Notification, once: Bool
    ) raises -> Self:
        var listeners = self._state[].events.notifications(event)
        if event == "readable":
            self._activate()
        listeners.add(callback, once)
        if event == "readable":
            self._state[].flowing = False
            self._state[].readable_pending = (
                len(self._state[].chunks) != 0 or self._state[].eof
            )
        return self

    def off_empty(
        mut self, event: String, callback: Notification
    ) raises -> Self:
        self._state[].events.notifications(event).remove(callback)
        if (
            event == "readable"
            and not self._state[].events.has("readable")
            and self._state[].events.state[].data.has_listeners()
            and not self._state[].paused
        ):
            _ = self.resume()
        return self

    def on_error(
        mut self, event: String, callback: ReadErrorCallback
    ) raises -> Self:
        return self._add_error(event, callback, False)

    def once_error(
        mut self, event: String, callback: ReadErrorCallback
    ) raises -> Self:
        return self._add_error(event, callback, True)

    def _add_error(
        mut self, event: String, callback: ReadErrorCallback, once: Bool
    ) raises -> Self:
        if event != "error":
            raise Error("Unsupported readable error event: ", event)
        self._state[].events.state[].errors.add(callback, once)
        return self

    def off_error(
        mut self, event: String, callback: ReadErrorCallback
    ) raises -> Self:
        if event != "error":
            raise Error("Unsupported readable error event: ", event)
        self._state[].events.state[].errors.remove(callback)
        return self


def _initial_readables() -> List[ArcPointer[_ReadableState]]:
    return List[ArcPointer[_ReadableState]]()


comptime _readable_sources = GlobalCell[
    "tsonic.node.stream.readables", _initial_readables
]()


def _prune_readables():
    var retained = List[ArcPointer[_ReadableState]]()
    for owner in _readable_sources.get()[]:
        var source = Readable(owner)
        _ = source._prune_sinks()
        var needed = (
            owner[].native_read
            or owner[].resume_pending
            or owner[].events.has("readable")
            or not owner[].paused
            and owner[].flowing
        )
        var pending_pipe_end = (
            len(owner[].pipes) != 0
            and owner[].ended
            and not owner[].events.state[].ended
            and not owner[].events.state[].closed
            and not owner[].failed
        )
        if (
            pending_pipe_end
            or needed
            and not owner[].closed
            and not owner[].failed
            and not owner[].ended
        ):
            retained.append(owner)
        else:
            owner[].registered = False
    _readable_sources.get()[] = retained^


def has_active_readables() -> Bool:
    _prune_readables()
    return len(_readable_sources.get()[]) != 0


def poll_readables() raises -> Bool:
    var worked = False
    var snapshot = _readable_sources.get()[].copy()
    try:
        for state in snapshot:
            var source = Readable(state)
            worked = source._poll() or worked
    finally:
        _prune_readables()
    return worked
