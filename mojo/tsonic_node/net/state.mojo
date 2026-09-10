from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer
from tsonic_runtime import TsError
from ..internal.network_endpoint import NetworkEndpoint, monotonic_milliseconds
from ..internal.typed_listeners import TypedListeners


@fieldwise_init
struct WriteChunk(Movable):
    var bytes: List[Byte]
    var offset: Int


struct SocketState(Movable):
    var endpoint: NetworkEndpoint
    var writes: List[Optional[WriteChunk]]
    var write_index: Int
    var queued_bytes: Int
    var bytes_read: Int64
    var bytes_written: Int64
    var destroyed: Bool
    var connected: Bool
    var referenced: Bool
    var paused: Bool
    var flowing: Bool
    var allow_half_open: Bool
    var read_ended: Bool
    var end_pending: Bool
    var write_ending: Bool
    var write_ended: Bool
    var finish_pending: Bool
    var close_pending: Bool
    var need_drain: Bool
    var readable_notified: Bool
    var error: Optional[Error]
    var had_error: Bool
    var no_delay: Optional[Bool]
    var timeout: Float64
    var timeout_armed: Bool
    var last_activity: Float64
    var data: TypedListeners[Tuple[Buffer]]
    var errors: TypedListeners[Tuple[TsError]]
    var connects: TypedListeners[Tuple[]]
    var ends: TypedListeners[Tuple[]]
    var finishes: TypedListeners[Tuple[]]
    var drains: TypedListeners[Tuple[]]
    var timeouts: TypedListeners[Tuple[]]
    var readable: TypedListeners[Tuple[]]
    var closes: TypedListeners[Tuple[Bool]]

    def __init__(
        out self,
        endpoint: NetworkEndpoint,
        connected: Bool,
        allow_half_open: Bool,
    ):
        self.endpoint = endpoint
        self.writes = List[Optional[WriteChunk]]()
        self.write_index = 0
        self.queued_bytes = 0
        self.bytes_read = 0
        self.bytes_written = 0
        self.destroyed = False
        self.connected = connected
        self.referenced = True
        self.paused = False
        self.flowing = False
        self.allow_half_open = allow_half_open
        self.read_ended = False
        self.end_pending = False
        self.write_ending = False
        self.write_ended = False
        self.finish_pending = False
        self.close_pending = False
        self.need_drain = False
        self.readable_notified = False
        self.error = None
        self.had_error = False
        self.no_delay = None
        self.timeout = 0
        self.timeout_armed = False
        self.last_activity = monotonic_milliseconds()
        self.data = TypedListeners[Tuple[Buffer]]()
        self.errors = TypedListeners[Tuple[TsError]]()
        self.connects = TypedListeners[Tuple[]]()
        self.ends = TypedListeners[Tuple[]]()
        self.finishes = TypedListeners[Tuple[]]()
        self.drains = TypedListeners[Tuple[]]()
        self.timeouts = TypedListeners[Tuple[]]()
        self.readable = TypedListeners[Tuple[]]()
        self.closes = TypedListeners[Tuple[Bool]]()


def activity(state: ArcPointer[SocketState]):
    state[].last_activity = monotonic_milliseconds()
    state[].timeout_armed = state[].timeout > 0


def destroy(state: ArcPointer[SocketState]):
    if state[].destroyed:
        return
    state[].endpoint.close()
    state[].destroyed = True
    state[].close_pending = True
    state[].writes = List[Optional[WriteChunk]]()
    state[].queued_bytes = 0
    state[].write_index = 0
    state[].timeout_armed = False


def fail(state: ArcPointer[SocketState], error: Error):
    if not state[].error:
        state[].error = error
    state[].had_error = True
    destroy(state)


def unsettled(state: ArcPointer[SocketState]) -> Bool:
    return not state[].destroyed or state[].close_pending or Bool(state[].error)
