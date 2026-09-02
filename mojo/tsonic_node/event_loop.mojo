from std.time import sleep

from .http import has_active_servers, poll_servers
from .timers import has_refed_timers, next_timer_delay_ns, poll_timers


def run_event_loop() raises:
    while has_refed_timers() or has_active_servers():
        var timer_work = poll_timers()
        var server_work = poll_servers()
        if timer_work or server_work:
            continue
        var delay = next_timer_delay_ns()
        var sleep_ns = min(delay.value(), 10_000_000) if delay else 10_000_000
        sleep(Float64(sleep_ns) / 1_000_000_000.0)
