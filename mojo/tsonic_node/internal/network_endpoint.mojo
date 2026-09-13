from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer

from ..validation import checked_integer


@fieldwise_init
struct AddressInfo(ImplicitlyCopyable):
    var address: String
    var family: String
    var port: Float64


struct _EndpointOwner(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_net_endpoint_free", NoneType](
                self.handle.value()
            )


struct NetworkEndpoint(ImplicitlyCopyable):
    var _owner: ArcPointer[_EndpointOwner]

    def __init__(out self):
        self._owner = ArcPointer(_EndpointOwner(None))

    def __init__(
        out self,
        host: String,
        port: Float64,
        listener: Bool,
        backlog: Float64 = 511,
    ) raises:
        var native_port = Int32(checked_integer(port, 65535, "port"))
        var native_backlog = Int32(
            checked_integer(backlog, 2147483647, "backlog")
        )
        if host.find("\0") >= 0:
            raise Error("Network host contains a null byte")
        var native_host = host
        var handle = external_call[
            "tsonic_node_net_endpoint_new",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](
            native_host.as_c_string_slice().ptr().as_unsafe_any_origin(),
            native_port,
            c_int(listener),
            native_backlog,
        )
        if not handle:
            raise Error("Unable to allocate network endpoint")
        self._owner = ArcPointer(_EndpointOwner(handle))

    def __init__(
        out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    ):
        self._owner = ArcPointer(_EndpointOwner(handle))

    def close(self):
        if not self._owner[].handle:
            return
        external_call["tsonic_node_net_endpoint_close", NoneType](
            self._owner[].handle.value()
        )

    def progress(self) -> Int32:
        if not self._owner[].handle:
            return 0
        return external_call["tsonic_node_net_endpoint_progress", c_int](
            self._owner[].handle.value()
        )

    def descriptor(self) -> Int32:
        if not self._owner[].handle:
            return -1
        return external_call["tsonic_node_net_endpoint_descriptor", c_int](
            self._owner[].handle.value()
        )

    def accept(self) raises -> Optional[Self]:
        var status = Int32(0)
        var handle = external_call[
            "tsonic_node_net_endpoint_accept",
            OptionalPointer[NoneType, MutUntrackedOrigin],
        ](
            self._owner[].handle.value(),
            Pointer(to=status),
        )
        if status != 0:
            raise network_error(status)
        return Self(handle) if handle else Optional[Self]()

    def no_delay(self, enabled: Bool) raises:
        var status = external_call["tsonic_node_net_endpoint_no_delay", c_int](
            self._owner[].handle.value(),
            c_int(enabled),
        )
        if status != 0:
            raise network_error(status)

    def shutdown(self) raises:
        var status = external_call["tsonic_node_net_endpoint_shutdown", c_int](
            self._owner[].handle.value()
        )
        if status != 0:
            raise network_error(status)

    def address(self, peer: Bool = False) raises -> Optional[AddressInfo]:
        if self.progress() != 1:
            return None
        var bytes = List[Byte](capacity=46)
        for _ in range(46):
            bytes.append(0)
        var port = Int32(0)
        var family = Int32(0)
        var status = external_call["tsonic_node_net_endpoint_address", c_int](
            self._owner[].handle.value(),
            c_int(peer),
            bytes.unsafe_ptr(),
            c_size_t(len(bytes)),
            Pointer(to=port),
            Pointer(to=family),
        )
        if status != 0:
            raise network_error(status)
        return AddressInfo(
            String(
                unsafe_from_utf8_ptr=bytes.unsafe_ptr().unsafe_bitcast[UInt8]()
            ),
            "IPv4" if family == 4 else "IPv6",
            Float64(port),
        )


def network_error(status: Int32) -> Error:
    var name = external_call["uv_err_name", Pointer[UInt8, ImmUntrackedOrigin]](
        status
    )
    var text = external_call["uv_strerror", Pointer[UInt8, ImmUntrackedOrigin]](
        status
    )
    return Error(
        String(unsafe_from_utf8_ptr=name)
        + ": "
        + String(unsafe_from_utf8_ptr=text)
    )


def poll_network_resolution() -> Bool:
    return external_call["tsonic_node_net_resolution_poll", c_int]() != 0


def has_network_resolution() -> Bool:
    return external_call["tsonic_node_net_resolution_pending", c_int]() != 0


def monotonic_milliseconds() -> Float64:
    return Float64(external_call["uv_hrtime", UInt64]()) / 1000000.0
