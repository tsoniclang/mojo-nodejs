from std.collections import List
from std.memory import ArcPointer
from std.time import monotonic
from tsonic_runtime import GlobalCell, RaisingCallable


comptime TimerCallback = RaisingCallable[Tuple[], NoneType]


@fieldwise_init
struct TimerState:
    var callback: TimerCallback
    var delay_ns: Int
    var due_ns: Int
    var interval: Bool
    var active: Bool
    var referenced: Bool


struct Timeout(ImplicitlyCopyable):
    var _state: ArcPointer[TimerState]

    def __init__(out self, state: ArcPointer[TimerState]):
        self._state = state

    def has_ref(self) -> Bool:
        return self._state[].active and self._state[].referenced

    def unref(self) -> Self:
        self._state[].referenced = False
        return self

    def ref(self) -> Self:
        self._state[].referenced = True
        return self

    def refresh(self) -> Self:
        self._state[].due_ns = monotonic() + self._state[].delay_ns
        return self

    def close(self) -> Self:
        self._state[].active = False
        return self


def _initial_timers() -> List[Timeout]:
    return List[Timeout]()


comptime _timers = GlobalCell["tsonic.node.timers", _initial_timers]()
comptime _max_timers = 1 << 20


def set_timeout(callback: TimerCallback, delay_ms: Int32) raises -> Timeout:
    return _schedule(callback, delay_ms, False)


def set_interval(callback: TimerCallback, delay_ms: Int32) raises -> Timeout:
    return _schedule(callback, delay_ms, True)


def clear_timeout(timeout: Timeout):
    _ = timeout.close()


def clear_interval(timeout: Timeout):
    _ = timeout.close()


def has_refed_timers() -> Bool:
    for index in range(len(_timers.get()[])):
        if _timers.get()[][index].has_ref():
            return True
    return False


def next_timer_delay_ns() -> Optional[Int]:
    var now = monotonic()
    var selected: Optional[Int] = None
    for index in range(len(_timers.get()[])):
        var timer = _timers.get()[][index]
        if not timer.has_ref():
            continue
        var remaining = max(timer._state[].due_ns - now, 0)
        if not selected or remaining < selected.value():
            selected = Optional(remaining)
    return selected


def poll_timers() raises -> Bool:
    var now = monotonic()
    var did_work = False
    var retained = List[Timeout](capacity=len(_timers.get()[]))
    for index in range(len(_timers.get()[])):
        var timer = _timers.get()[][index]
        if not timer._state[].active:
            continue
        if timer._state[].due_ns <= now:
            timer._state[].callback.call(())
            did_work = True
            if timer._state[].interval and timer._state[].active:
                timer._state[].due_ns = now + timer._state[].delay_ns
            else:
                timer._state[].active = False
        if timer._state[].active:
            retained.append(timer)
    _timers.get()[] = retained^
    return did_work


def _schedule(
    callback: TimerCallback,
    delay_ms: Int32,
    interval: Bool,
) raises -> Timeout:
    if len(_timers.get()[]) >= _max_timers:
        raise Error("Active Node timers exceed the finite runtime limit")
    var delay_ns = max(Int(delay_ms), 0) * 1_000_000
    if interval:
        delay_ns = max(delay_ns, 1_000_000)
    var timeout = Timeout(
        ArcPointer(
            TimerState(
                callback,
                delay_ns,
                monotonic() + delay_ns,
                interval,
                True,
                True,
            )
        )
    )
    _timers.get()[].append(timeout)
    return timeout^
