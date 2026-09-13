from std.collections import List
from std.utils import Variant
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable, TsError
from ..buffer import Buffer
from ..internal.network_endpoint import monotonic_milliseconds, network_error
from ..internal.typed_listeners import TypedListeners
from ..net.options import timeout_duration
from .state import _TlsServerNativeState
from .native import _take_error
from .events import SocketEvents, require_event

comptime EmptyCallback = RaisingCallable[Tuple[], NoneType]
comptime SocketCallback = RaisingCallable[Tuple[TLSSocket], NoneType]
comptime ClientErrorListeners = TypedListeners[Tuple[TsError, TLSSocket]]


struct _TlsSocketState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var referenced: Bool
    var scheduled: Bool
    var server_errors: Optional[ClientErrorListeners]
    var server_connections: Optional[TypedListeners[Tuple[TLSSocket]]]
    var native_owner: Optional[ArcPointer[_TlsServerNativeState]]
    var events: SocketEvents
    var secure_notified: Bool
    var end_notified: Bool
    var finish_notified: Bool
    var close_notified: Bool
    var paused: Bool
    var flowing: Bool
    var allow_half_open: Bool
    var readable_notified: Bool
    var need_drain: Bool
    var timeout: Float64
    var timeout_armed: Bool
    var last_activity: Float64
    var activity_bytes: UInt64
    var no_delay: Optional[Bool]
    var failure: Optional[Error]
    var had_error: Bool
    var handshake_deadline: Float64

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle
        self.referenced = True
        self.scheduled = False
        self.server_errors = None
        self.server_connections = None
        self.native_owner = None
        self.events = SocketEvents()
        self.secure_notified = False
        self.end_notified = False
        self.finish_notified = False
        self.close_notified = False
        self.paused = False
        self.flowing = False
        self.allow_half_open = False
        self.readable_notified = False
        self.need_drain = False
        self.timeout = 0
        self.timeout_armed = False
        self.last_activity = monotonic_milliseconds()
        self.activity_bytes = 0
        self.no_delay = None
        self.failure = None
        self.had_error = False
        self.handshake_deadline = 0

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_tls_socket_free", NoneType](
                self.handle.value()
            )


struct TLSSocket(ImplicitlyCopyable):
    var _state: ArcPointer[_TlsSocketState]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ) raises:
        if not handle:
            raise Error("TLS socket handle is absent")
        self._state = ArcPointer(_TlsSocketState(handle))
        if len(_activities.get()[]) >= 1048576:
            prune_sockets()
        if len(_activities.get()[]) >= 1048576:
            raise Error("TLS sockets exceed the finite runtime limit")
        _schedule_socket(self)

    def write_buffer(self, value: Buffer) raises -> Bool:
        var bytes = value.copy_bytes()
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var written = external_call["tsonic_node_tls_write", Int64](
            self._handle(),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            Pointer(to=error),
        )
        if written < 0 or written != Int64(len(bytes)):
            raise Error(_take_error(error, "TLS write failed"))
        _schedule_socket(self)
        var writable = self.queued_bytes() < 65536
        self._state[].need_drain = self._state[].need_drain or not writable
        return writable

    def write_string(self, value: String) raises -> Bool:
        return self.write_buffer(Buffer.from_string(value))

    def read(self) raises -> Optional[Buffer]:
        var bytes = List[Byte](capacity=65536)
        for _ in range(65536):
            bytes.append(Byte(0))
        var count = self.read_into(bytes)
        if count <= 0:
            return None
        var result = List[Byte](capacity=Int(count))
        for index in range(Int(count)):
            result.append(bytes[index])
        return Optional(Buffer(result^))

    def end(self) raises -> Self:
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        if (
            external_call["tsonic_node_tls_end", c_int](
                self._handle(), Pointer(to=error)
            )
            == 0
        ):
            raise Error(_take_error(error, "Unable to close TLS socket"))
        _schedule_socket(self)
        return self

    def end_buffer(self, value: Buffer) raises -> Self:
        _ = self.write_buffer(value)
        return self.end()

    def end_string(self, value: String) raises -> Self:
        _ = self.write_string(value)
        return self.end()

    def finish_response(self) raises:
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        if (
            external_call["tsonic_node_tls_finish_response", c_int](
                self._handle(), Pointer(to=error)
            )
            == 0
        ):
            raise Error(_take_error(error, "Unable to finish TLS response"))
        _schedule_socket(self)

    def destroy(self) -> Self:
        external_call["tsonic_node_tls_destroy", NoneType](self._handle())
        self._state[].native_owner = None
        self._state[].timeout_armed = False
        return self

    def fail(self, error: Error):
        if not self._state[].failure:
            self._state[].failure = error
        self._state[].had_error = True
        _ = self.destroy()

    def ready(self) -> Bool:
        return (
            external_call["tsonic_node_tls_ready", c_int](self._handle()) != 0
        )

    def closed(self) -> Bool:
        return (
            external_call["tsonic_node_tls_closed", c_int](self._handle()) != 0
        )

    def read_into(self, mut bytes: List[Byte]) raises -> Int:
        self._state[].readable_notified = False
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var count = external_call["tsonic_node_tls_read", Int64](
            self._handle(),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            Pointer(to=error),
        )
        if count == -1:
            var failure = Error(_take_error(error, "TLS read failed"))
            self.fail(failure)
            raise failure^
        return Int(count)

    def peek(self) raises -> Int:
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var result = external_call["tsonic_node_tls_peek", c_int](
            self._handle(), Pointer(to=error)
        )
        if result == -1:
            raise Error(_take_error(error, "TLS read failed"))
        return Int(result)

    def progress(self) raises:
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        if (
            external_call["tsonic_node_tls_progress", c_int](
                self._handle(), Pointer(to=error)
            )
            < 0
        ):
            raise Error(_take_error(error, "TLS transport failed"))

    def pending(self) -> Bool:
        return (
            external_call["tsonic_node_tls_pending", c_int](self._handle()) != 0
        )

    def read_ended(self) -> Bool:
        return (
            external_call["tsonic_node_tls_read_ended", c_int](self._handle())
            != 0
        )

    def write_ended(self) -> Bool:
        return (
            external_call["tsonic_node_tls_write_ended", c_int](self._handle())
            != 0
        )

    def queued_bytes(self) -> Int:
        return Int(
            external_call["tsonic_node_tls_queued_bytes", UInt64](
                self._handle()
            )
        )

    def activity_bytes(self) -> UInt64:
        return external_call["tsonic_node_tls_activity_bytes", UInt64](
            self._handle()
        )

    def pause(self) -> Self:
        self._state[].paused = True
        return self

    def resume(self) -> Self:
        self._state[].paused = False
        self._state[].flowing = True
        return self

    def is_paused(self) -> Bool:
        return self._state[].paused

    def set_no_delay(self, enabled: Bool = True) raises -> Self:
        self._state[].no_delay = enabled
        if self.ready() and not self.closed():
            var status = external_call["tsonic_node_tls_set_no_delay", c_int](
                self._handle(), c_int(enabled)
            )
            if status != 0:
                raise network_error(status)
        return self

    def set_timeout(self, timeout: Float64) raises -> Self:
        if self.closed():
            return self
        self._state[].timeout = timeout_duration(timeout)
        self._state[].last_activity = monotonic_milliseconds()
        self._state[].timeout_armed = self._state[].timeout > 0
        return self

    def set_timeout_callback(
        self, timeout: Float64, callback: EmptyCallback
    ) raises -> Self:
        if self.closed():
            return self
        _ = self.set_timeout(timeout)
        if timeout == 0:
            self._state[].events.timeouts.remove(callback)
        else:
            self._state[].events.timeouts.add(callback, True)
        return self

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def unref(self) -> Self:
        self._state[].referenced = False
        return self

    def authorized(self) -> Bool:
        return Bool(
            external_call["tsonic_node_tls_authorized", c_int](self._handle())
        )

    def authorization_error(self) -> Optional[String]:
        var value = external_call[
            "tsonic_node_tls_authorization_error",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        return Optional(
            String(unsafe_from_utf8_ptr=value.value())
        ) if value else None

    def encrypted(self) -> Bool:
        return True

    def servername_value(self) -> Optional[Variant[String, Bool]]:
        if not self.ready():
            return None
        var value = external_call[
            "tsonic_node_tls_servername",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        var name = String(unsafe_from_utf8_ptr=value.value()) if value else ""
        if name.byte_length() == 0:
            return Optional(Variant[String, Bool](False))
        return Optional(Variant[String, Bool](name^))

    def alpn_protocol(self) -> Variant[String, Bool]:
        var value = external_call[
            "tsonic_node_tls_alpn",
            OptionalPointer[UInt8, ImmUntrackedOrigin],
        ](self._handle())
        return Variant[String, Bool](
            String(unsafe_from_utf8_ptr=value.value())
        ) if value else Variant[String, Bool](False)

    def bytes_read(self) -> Float64:
        return Float64(
            external_call["tsonic_node_tls_bytes_read", UInt64](self._handle())
        )

    def bytes_written(self) -> Float64:
        return Float64(
            external_call["tsonic_node_tls_bytes_written", UInt64](
                self._handle()
            )
        )

    def on_data(
        self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]
    ) raises -> Self:
        require_event(event, "data")
        self._state[].events.data.add(callback)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def once_data(
        self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]
    ) raises -> Self:
        require_event(event, "data")
        self._state[].events.data.add(callback, True)
        if not self._state[].paused:
            self._state[].flowing = True
        return self

    def off_data(
        self, event: String, callback: RaisingCallable[Tuple[Buffer], NoneType]
    ) raises -> Self:
        require_event(event, "data")
        self._state[].events.data.remove(callback)
        return self

    def on_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].events.errors.add(callback)
        return self

    def once_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].events.errors.add(callback, True)
        return self

    def off_error(
        self, event: String, callback: RaisingCallable[Tuple[TsError], NoneType]
    ) raises -> Self:
        require_event(event, "error")
        self._state[].events.errors.remove(callback)
        return self

    def on_close(
        self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]
    ) raises -> Self:
        require_event(event, "close")
        self._state[].events.closes.add(callback)
        return self

    def once_close(
        self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]
    ) raises -> Self:
        require_event(event, "close")
        self._state[].events.closes.add(callback, True)
        return self

    def off_close(
        self, event: String, callback: RaisingCallable[Tuple[Bool], NoneType]
    ) raises -> Self:
        require_event(event, "close")
        self._state[].events.closes.remove(callback)
        return self

    def on_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._state[].events.empty(event).add(callback)
        return self

    def once_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._state[].events.empty(event).add(callback, True)
        return self

    def off_empty(self, event: String, callback: EmptyCallback) raises -> Self:
        self._state[].events.empty(event).remove(callback)
        return self

    def _handle(self) -> Pointer[NoneType, MutUntrackedOrigin]:
        return self._state[].handle.value()


def _initial_activities() -> List[TLSSocket]:
    return List[TLSSocket]()


comptime _activities = GlobalCell[
    "tsonic.node.tls.activities", _initial_activities
]()


def _schedule_socket(socket: TLSSocket):
    if not socket._state[].scheduled:
        socket._state[].scheduled = True
        _activities.get()[].append(socket)


def prune_sockets():
    var retained = List[TLSSocket]()
    for socket in _activities.get()[]:
        if (
            not socket.closed()
            or not socket._state[].close_notified
            or socket._state[].failure
        ):
            retained.append(socket)
        else:
            socket._state[].scheduled = False
    _activities.get()[] = retained^
