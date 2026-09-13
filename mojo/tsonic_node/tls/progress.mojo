from tsonic_runtime import error_new
from ..buffer import Buffer
from ..internal.network_endpoint import monotonic_milliseconds
from .socket import TLSSocket


def progress_socket(socket: TLSSocket) raises -> Bool:
    var worked = False
    if not socket.closed():
        try:
            if (
                not socket.ready()
                and socket._state[].handshake_deadline > 0
                and monotonic_milliseconds()
                >= socket._state[].handshake_deadline
            ):
                raise Error("TLS connection handshake timed out")
            socket.progress()
        except error:
            socket.fail(error)
            worked = True
    var activity = socket.activity_bytes()
    if activity != socket._state[].activity_bytes:
        socket._state[].activity_bytes = activity
        socket._state[].last_activity = monotonic_milliseconds()
        socket._state[].timeout_armed = socket._state[].timeout > 0
        worked = True
    if (
        socket.ready()
        and not socket.closed()
        and not socket._state[].secure_notified
    ):
        socket._state[].secure_notified = True
        socket._state[].native_owner = None
        socket._state[].server_errors = None
        if socket._state[].no_delay:
            try:
                _ = socket.set_no_delay(socket._state[].no_delay.value())
            except error:
                socket.fail(error)
        if not socket.closed():
            if socket._state[].server_connections:
                var listeners = socket._state[].server_connections.take()
                _ = listeners.emit((socket,))
            else:
                _ = socket._state[].events.secure.emit(())
        worked = True
    if socket.ready() and not socket.closed():
        if not socket._state[].paused and not socket.read_ended():
            if socket._state[].flowing:
                var received = 0
                while (
                    received < 65536
                    and not socket.closed()
                    and not socket._state[].paused
                ):
                    var chunk: Optional[Buffer] = None
                    try:
                        chunk = socket.read()
                    except error:
                        socket.fail(error)
                        break
                    if not chunk:
                        break
                    received += len(chunk.value())
                    _ = socket._state[].events.data.emit((chunk.value(),))
                    worked = True
            else:
                var readiness = -2
                try:
                    readiness = socket.peek()
                except error:
                    socket.fail(error)
                if (
                    readiness > 0
                    and socket._state[].events.readable.has_listeners()
                    and not socket._state[].readable_notified
                ):
                    socket._state[].readable_notified = True
                    _ = socket._state[].events.readable.emit(())
                    worked = True
        if (
            socket._state[].need_drain
            and socket.queued_bytes() == 0
            and not socket.closed()
        ):
            socket._state[].need_drain = False
            _ = socket._state[].events.drains.emit(())
            worked = True
    if (
        socket.read_ended()
        and not socket._state[].end_notified
        and not socket._state[].had_error
    ):
        socket._state[].end_notified = True
        if not socket._state[].allow_half_open:
            try:
                _ = socket.end()
            except error:
                socket.fail(error)
        _ = socket._state[].events.ends.emit(())
        worked = True
    if socket.write_ended() and not socket._state[].finish_notified:
        socket._state[].finish_notified = True
        _ = socket._state[].events.finishes.emit(())
        worked = True
    if not socket.closed() and socket._state[].timeout_armed:
        var latest_activity = socket.activity_bytes()
        if latest_activity != socket._state[].activity_bytes:
            socket._state[].activity_bytes = latest_activity
            socket._state[].last_activity = monotonic_milliseconds()
        if (
            monotonic_milliseconds() - socket._state[].last_activity
            >= socket._state[].timeout
        ):
            socket._state[].timeout_armed = False
            _ = socket._state[].events.timeouts.emit(())
            worked = True
    if socket._state[].failure:
        var error = socket._state[].failure.take()
        if socket._state[].server_errors:
            var listeners = socket._state[].server_errors.take()
            _ = listeners.emit((error_new(String(error)), socket))
        elif socket._state[].events.errors.has_listeners():
            _ = socket._state[].events.errors.emit((error_new(String(error)),))
        else:
            raise error^
        worked = True
    if socket.closed() and not socket._state[].close_notified:
        socket._state[].close_notified = True
        _ = socket._state[].events.closes.emit((socket._state[].had_error,))
        worked = True
    return worked
