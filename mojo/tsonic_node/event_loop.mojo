from std.time import sleep

from .http import has_active_servers, poll_servers
from .https import has_active_https, poll_https
from .dns import has_pending_dns, poll_dns
from .net import has_active_net, poll_net
from .timers import has_refed_timers, next_timer_delay_ns, poll_timers
from .tls import has_active_tls, poll_tls
from .zlib import has_pending_zlib, poll_zlib
from .worker_threads import has_active_worker_threads, poll_worker_threads


def run_event_loop() raises:
    while (
        has_refed_timers()
        or has_active_servers()
        or has_pending_dns()
        or has_active_net()
        or has_active_tls()
        or has_pending_zlib()
        or has_active_https()
        or has_active_worker_threads()
    ):
        var timer_work = poll_timers()
        var server_work = poll_servers()
        var dns_work = poll_dns()
        var net_work = poll_net()
        var tls_work = poll_tls()
        var zlib_work = poll_zlib()
        var https_work = poll_https()
        var worker_work = poll_worker_threads()
        if (
            timer_work
            or server_work
            or dns_work
            or net_work
            or tls_work
            or zlib_work
            or https_work
            or worker_work
        ):
            continue
        var delay = next_timer_delay_ns()
        var sleep_ns = min(delay.value(), 10_000_000) if delay else 10_000_000
        sleep(Float64(sleep_ns) / 1_000_000_000.0)
