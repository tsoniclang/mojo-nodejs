from std.collections import List
from std.ffi import c_int, c_size_t, external_call, get_errno
from std.memory import ArcPointer
from ..buffer import Buffer
from ..internal.network_endpoint import network_error
from .state import SocketState, WriteChunk, activity, destroy, fail


def socket_error() -> Error:
    return network_error(
        external_call["uv_translate_sys_error", c_int](get_errno())
    )


def read(state: ArcPointer[SocketState]) -> Optional[Buffer]:
    if state[].destroyed or not state[].connected or state[].read_ended:
        return None
    var bytes = List[Byte](capacity=65536)
    for _ in range(65536):
        bytes.append(0)
    var count = external_call["tsonic_node_socket_read", Int64](
        state[].endpoint.descriptor(),
        bytes.unsafe_ptr(),
        c_size_t(len(bytes)),
    )
    if count == -2:
        return None
    if count < 0:
        fail(state, socket_error())
        return None
    state[].readable_notified = False
    if count == 0:
        state[].read_ended = True
        state[].end_pending = True
        return None
    bytes.shrink(Int(count))
    state[].bytes_read += count
    activity(state)
    return Buffer(bytes^)


def enqueue(state: ArcPointer[SocketState], value: Buffer) raises -> Bool:
    if state[].destroyed or state[].write_ending:
        raise Error("Cannot write after ending a network socket")
    if len(value) > 268435456 - state[].queued_bytes:
        raise Error("Network write queue exceeds the finite runtime limit")
    if len(value) != 0:
        state[].writes.append(Optional(WriteChunk(value.copy_bytes(), 0)))
        state[].queued_bytes += len(value)
        state[].bytes_written += Int64(len(value))
    _ = flush(state)
    var accepted = state[].queued_bytes < 65536 and not state[].destroyed
    if not accepted:
        state[].need_drain = True
    return accepted


def flush(state: ArcPointer[SocketState]) -> Bool:
    if state[].destroyed or not state[].connected:
        return False
    var budget = 65536
    var progressed = False
    while state[].write_index < len(state[].writes) and budget > 0:
        ref chunk = state[].writes[state[].write_index].value()
        var capacity = min(budget, len(chunk.bytes) - chunk.offset)
        var count = external_call["tsonic_node_socket_write", Int64](
            state[].endpoint.descriptor(),
            chunk.bytes.unsafe_ptr().unsafe_offset(chunk.offset),
            c_size_t(capacity),
        )
        if count == -2:
            return progressed
        if count <= 0:
            fail(
                state,
                socket_error() if count
                < 0 else Error("Network write made no progress"),
            )
            return True
        chunk.offset += Int(count)
        var complete = chunk.offset == len(chunk.bytes)
        state[].queued_bytes -= Int(count)
        budget -= Int(count)
        progressed = True
        activity(state)
        if complete:
            state[].writes[state[].write_index] = None
            state[].write_index += 1
    if state[].write_index == len(state[].writes):
        state[].writes = List[Optional[WriteChunk]]()
        state[].write_index = 0
    elif state[].write_index >= 64 and state[].write_index * 2 >= len(
        state[].writes
    ):
        var retained = List[Optional[WriteChunk]]()
        for index in range(state[].write_index, len(state[].writes)):
            retained.append(Optional(state[].writes[index].take()))
        state[].writes = retained^
        state[].write_index = 0
    if (
        state[].write_ending
        and not state[].write_ended
        and state[].queued_bytes == 0
    ):
        try:
            state[].endpoint.shutdown()
        except error:
            fail(state, error)
            return True
        state[].write_ended = True
        state[].finish_pending = True
        progressed = True
    return progressed


def end(state: ArcPointer[SocketState]) raises:
    if state[].destroyed:
        raise Error("Network socket is closed")
    state[].write_ending = True
    _ = flush(state)
