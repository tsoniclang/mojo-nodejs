from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from ..internal.network_endpoint import network_error


struct _ChannelOwner(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_worker_free", NoneType](self.handle.value())


@fieldwise_init
struct NativeMessage:
    var kind: UInt8
    var bytes: List[UInt8]


struct WorkerChannel(ImplicitlyCopyable):
    var _owner: ArcPointer[_ChannelOwner]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]):
        self._owner = ArcPointer(_ChannelOwner(handle))

    def close(self):
        external_call["tsonic_node_worker_close", NoneType](self._owner[].handle.value())

    def closed(self) -> Bool:
        return external_call["tsonic_node_worker_closed", c_int](self._owner[].handle.value()) != 0

    def progress(self) raises:
        _check(external_call["tsonic_node_worker_progress", c_int](self._owner[].handle.value()))

    def pending(self) -> Bool:
        return external_call["tsonic_node_worker_pending", c_int](self._owner[].handle.value()) != 0

    def send(self, kind: UInt8, bytes: List[UInt8]) raises:
        _check(external_call["tsonic_node_worker_send", c_int](
            self._owner[].handle.value(), kind, bytes.unsafe_ptr(), c_size_t(len(bytes)),
        ))

    def receive(self) raises -> Optional[NativeMessage]:
        self.progress()
        var kind = UInt8(0)
        var bytes = OptionalPointer[UInt8, ImmUntrackedOrigin]()
        var length = c_size_t(0)
        var present = external_call["tsonic_node_worker_message", c_int](
            self._owner[].handle.value(), Pointer(to=kind), Pointer(to=bytes), Pointer(to=length),
        )
        if present == 0:
            return None
        var result = List[UInt8](capacity=Int(length))
        for index in range(Int(length)):
            result.append(bytes.value()[index])
        external_call["tsonic_node_worker_consume", NoneType](self._owner[].handle.value())
        return NativeMessage(kind, result^)

    def wait_message(self, timeout_ms: Int32 = 30000) raises:
        _check(external_call["tsonic_node_worker_wait", c_int](self._owner[].handle.value(), timeout_ms))

    def flush(self, timeout_ms: Int32 = 30000) raises:
        _check(external_call["tsonic_node_worker_flush", c_int](self._owner[].handle.value(), timeout_ms))

    def exit_code(self) raises -> Optional[Int32]:
        var code = Int32(0)
        var status = external_call["tsonic_node_worker_exit", c_int](self._owner[].handle.value(), Pointer(to=code))
        if status < 0:
            _check(-status)
        return code if status != 0 else Optional[Int32]()

    def id(self) -> Float64:
        return Float64(external_call["tsonic_node_worker_id", c_int](self._owner[].handle.value()))

    def terminate(self) raises:
        _check(external_call["tsonic_node_worker_terminate", c_int](self._owner[].handle.value()))


def new_pair() raises -> Tuple[WorkerChannel, WorkerChannel]:
    var first = OptionalPointer[NoneType, MutUntrackedOrigin]()
    var second = OptionalPointer[NoneType, MutUntrackedOrigin]()
    _check(external_call["tsonic_node_worker_pair", c_int](Pointer(to=first), Pointer(to=second)))
    return (WorkerChannel(first), WorkerChannel(second))


def spawn_channel(arguments: String, environment: String, inherit_environment: Bool) raises -> WorkerChannel:
    var status = Int32(0)
    var handle = external_call["tsonic_node_worker_spawn", OptionalPointer[NoneType, MutUntrackedOrigin]](
        arguments.as_c_string_slice().ptr().as_unsafe_any_origin(), c_size_t(arguments.byte_length()),
        environment.as_c_string_slice().ptr().as_unsafe_any_origin(), c_size_t(environment.byte_length()),
        c_int(inherit_environment), Pointer(to=status),
    )
    _check(status)
    if not handle:
        raise Error("Worker creation returned no owned channel")
    return WorkerChannel(handle)


def adopt_channel() raises -> Optional[WorkerChannel]:
    var status = Int32(0)
    var handle = external_call["tsonic_node_worker_adopt", OptionalPointer[NoneType, MutUntrackedOrigin]](Pointer(to=status))
    _check(status)
    return WorkerChannel(handle) if handle else Optional[WorkerChannel]()


def current_worker_id() -> Float64:
    return Float64(external_call["tsonic_node_worker_self_id", c_int]())


def _check(status: Int32) raises:
    if status != 0:
        raise network_error(-status)
