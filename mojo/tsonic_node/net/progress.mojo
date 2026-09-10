from std.ffi import c_int, external_call
from std.memory import ArcPointer
from tsonic_runtime import error_new
from ..internal.network_endpoint import monotonic_milliseconds, network_error
from .state import SocketState, activity, destroy, fail
from .transport import flush, read, socket_error


def progress(state: ArcPointer[SocketState]) raises -> Bool:
    var worked = False
    if not state[].destroyed and not state[].connected:
        var status = state[].endpoint.progress()
        if status < 0:
            fail(state, network_error(status))
            worked = True
        elif status == 1:
            state[].connected = True
            activity(state)
            if state[].no_delay:
                try:
                    state[].endpoint.no_delay(state[].no_delay.value())
                except error:
                    fail(state, error)
            if not state[].destroyed:
                _ = state[].connects.emit(())
            worked = True
    if not state[].destroyed and state[].connected:
        worked = flush(state) or worked
        if (
            not state[].destroyed
            and not state[].read_ended
            and not state[].paused
        ):
            if state[].flowing:
                var received = 0
                while (
                    received < 65536
                    and not state[].destroyed
                    and not state[].paused
                ):
                    var chunk = read(state)
                    if not chunk:
                        break
                    received += len(chunk.value())
                    _ = state[].data.emit((chunk.value(),))
                    worked = True
            else:
                var ready = external_call["tsonic_node_socket_peek", c_int](
                    state[].endpoint.descriptor()
                )
                if ready == -1:
                    fail(state, socket_error())
                elif ready == 0:
                    state[].read_ended = True
                    state[].end_pending = True
                    worked = True
                elif (
                    ready > 0
                    and state[].readable.has_listeners()
                    and not state[].readable_notified
                ):
                    state[].readable_notified = True
                    _ = state[].readable.emit(())
                    worked = True
        if state[].end_pending and not state[].destroyed:
            state[].end_pending = False
            if not state[].allow_half_open:
                state[].write_ending = True
            _ = state[].ends.emit(())
            worked = True
        worked = flush(state) or worked
        if (
            state[].need_drain
            and state[].queued_bytes == 0
            and not state[].destroyed
        ):
            state[].need_drain = False
            _ = state[].drains.emit(())
            worked = True
        if state[].finish_pending and not state[].destroyed:
            state[].finish_pending = False
            _ = state[].finishes.emit(())
            worked = True
        if state[].read_ended and state[].write_ended:
            destroy(state)
            worked = True
        if not state[].destroyed and state[].timeout_armed:
            if (
                monotonic_milliseconds() - state[].last_activity
                >= state[].timeout
            ):
                state[].timeout_armed = False
                _ = state[].timeouts.emit(())
                worked = True
    if state[].error:
        var error = state[].error.take()
        if not state[].errors.has_listeners():
            raise error^
        _ = state[].errors.emit((error_new(String(error)),))
        worked = True
    if state[].close_pending:
        state[].close_pending = False
        _ = state[].closes.emit((state[].had_error,))
        worked = True
    return worked
