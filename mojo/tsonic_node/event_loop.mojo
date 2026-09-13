from std.ffi import c_int, external_call

from .http import has_active_servers, poll_servers
from .http.client import has_pending_requests, poll_requests
from .dns import has_pending_dns, poll_dns
from .net import has_active_net, poll_net
from .timers import has_refed_timers, next_timer_delay_ns, poll_timers
from .tls import has_active_tls, poll_tls
from .zlib import has_pending_zlib, poll_zlib
from .worker_threads import has_active_worker_threads, poll_worker_threads
from .filesystem.watch import has_active_watchers, poll_watchers
from .stream.completion import has_pending_streams, poll_streams
from .stream.readable import has_active_readables, poll_readables
from .readline import has_pending_readline, poll_readline


def run_event_loop() raises:
    while (
        has_refed_timers()
        or has_active_servers()
        or has_pending_requests()
        or has_pending_dns()
        or has_active_net()
        or has_active_tls()
        or has_pending_zlib()
        or has_active_worker_threads()
        or has_active_watchers()
        or has_pending_streams()
        or has_active_readables()
        or has_pending_readline()
    ):
        var read_epoch = external_call[
            "tsonic_node_stream_read_epoch", UInt64
        ]()
        var timer_work = poll_timers()
        var server_work = poll_servers()
        var request_work = poll_requests()
        var dns_work = poll_dns()
        var net_work = poll_net()
        var tls_work = poll_tls()
        var zlib_work = poll_zlib()
        var worker_work = poll_worker_threads()
        var watcher_work = poll_watchers()
        var stream_work = poll_streams()
        var readline_work = poll_readline()
        var readable_work = poll_readables()
        if (
            timer_work
            or server_work
            or request_work
            or dns_work
            or net_work
            or tls_work
            or zlib_work
            or worker_work
            or watcher_work
            or stream_work
            or readable_work
            or readline_work
        ):
            continue
        var delay = next_timer_delay_ns()
        var sleep_ns = min(delay.value(), 10_000_000) if delay else 10_000_000
        var waited = external_call["tsonic_node_stream_read_wait", c_int](
            read_epoch, UInt64(sleep_ns)
        )
        if waited < 0:
            raise Error("Native event-loop completion wait failed: ", waited)
