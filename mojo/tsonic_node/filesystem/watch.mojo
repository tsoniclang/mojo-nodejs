from std.collections import List, Span
from std.ffi import c_char, c_int, c_size_t, external_call, get_errno
from std.memory import ArcPointer
from tsonic_runtime import GlobalCell, RaisingCallable
from .core import Stats

comptime WatchListener = RaisingCallable[Tuple[String, Optional[String]], NoneType]
comptime StatListener = RaisingCallable[Tuple[Stats, Stats], NoneType]


struct WatchOptions(Copyable):
    var persistent: Optional[Bool]
    var recursive: Optional[Bool]
    var interval: Optional[Float64]

    def __init__(out self):
        self.persistent = None
        self.recursive = None
        self.interval = None


struct _WatchState(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var path: String
    var change: Optional[WatchListener]
    var stat: Optional[StatListener]

    def __init__(out self, handle: OptionalPointer[NoneType, MutUntrackedOrigin], path: String,
                 change: Optional[WatchListener], stat: Optional[StatListener]):
        self.handle = handle
        self.path = path
        self.change = change
        self.stat = stat

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_fs_watch_close", NoneType](self.handle.value())


struct FSWatcher(ImplicitlyCopyable):
    var _state: ArcPointer[_WatchState]

    def __init__(out self, state: ArcPointer[_WatchState]):
        self._state = state

    def close(self):
        if self._state[].handle:
            var handle = self._state[].handle.value()
            self._state[].handle = None
            self._state[].change = None
            self._state[].stat = None
            external_call["tsonic_node_fs_watch_close", NoneType](handle)

    def ref(self) -> Self:
        if self._state[].handle:
            external_call["tsonic_node_fs_watch_ref", NoneType](self._state[].handle.value(), c_int(1))
        return self

    def unref(self) -> Self:
        if self._state[].handle:
            external_call["tsonic_node_fs_watch_ref", NoneType](self._state[].handle.value(), c_int(0))
        return self

    def has_ref(self) -> Bool:
        return Bool(self._state[].handle) and external_call["tsonic_node_fs_watch_has_ref", c_int](self._state[].handle.value()) != 0


def _initial_watchers() -> List[FSWatcher]:
    return List[FSWatcher]()


comptime _watchers = GlobalCell["tsonic.node.fs.watchers", _initial_watchers]()


def _watch(path: String, options: WatchOptions, change: Optional[WatchListener], stat: Optional[StatListener]) raises -> FSWatcher:
    if path.find("\0") != -1:
        raise Error("A watched path cannot contain a null byte")
    var interval = options.interval.value() if options.interval else Float64(5007)
    if interval != interval or interval < 1 or interval > 4294967295 or interval != Float64(UInt32(interval)):
        raise Error("A watchFile interval must be a positive uint32 number of milliseconds")
    var handle = external_call["tsonic_node_fs_watch_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
        path.as_c_string_slice(), c_int(Bool(stat)), UInt32(interval),
        c_int(options.recursive.value() if options.recursive else False),
        c_int(options.persistent.value() if options.persistent else True),
    )
    if not handle:
        raise Error("Unable to watch path: ", get_errno())
    var watcher = FSWatcher(ArcPointer(_WatchState(handle, path, change, stat)))
    _watchers.get()[].append(watcher)
    return watcher


def watch(path: String) raises -> FSWatcher:
    return _watch(path, WatchOptions(), None, None)


def watch(path: String, listener: WatchListener) raises -> FSWatcher:
    return _watch(path, WatchOptions(), Optional(listener), None)


def watch(path: String, options: WatchOptions, listener: WatchListener) raises -> FSWatcher:
    return _watch(path, options, Optional(listener), None)


def watch_file(path: String, listener: StatListener) raises -> FSWatcher:
    return _watch(path, WatchOptions(), None, Optional(listener))


def watch_file(path: String, options: WatchOptions, listener: StatListener) raises -> FSWatcher:
    return _watch(path, options, None, Optional(listener))


def unwatch_file(path: String):
    var snapshot = _watchers.get()[].copy()
    for watcher in snapshot:
        if watcher._state[].stat and watcher._state[].path == path:
            watcher.close()


def has_active_watchers() -> Bool:
    return external_call["tsonic_node_fs_watch_alive", c_int]() != 0


def _snapshot(event: Pointer[NoneType, MutUntrackedOrigin], previous: Bool) -> Stats:
    var fields = List[Int]()
    for field in range(10):
        fields.append(Int(external_call["tsonic_node_fs_event_stat", Int64](event, c_int(previous), c_int(field))))
    var mtime = external_call["tsonic_node_fs_event_time", Float64](event, c_int(previous), c_int(1))
    return Stats(fields[0], mtime, fields[1], fields[2], fields[3], fields[4], fields[5], fields[6],
                 fields[7] != 0, fields[8] != 0, fields[9] != 0,
                 external_call["tsonic_node_fs_event_time", Float64](event, c_int(previous), c_int(0)),
                 external_call["tsonic_node_fs_event_time", Float64](event, c_int(previous), c_int(2)),
                 external_call["tsonic_node_fs_event_time", Float64](event, c_int(previous), c_int(3)))


def poll_watchers() raises -> Bool:
    external_call["tsonic_node_fs_watch_poll", NoneType]()
    var snapshot = _watchers.get()[].copy()
    var did_work = False
    for watcher in snapshot:
        while watcher._state[].handle:
            var handle = watcher._state[].handle.value()
            var error = external_call["tsonic_node_fs_watch_error", c_int](handle)
            if error != 0:
                watcher.close()
                raise Error("Filesystem watcher queue failed: ", error)
            var event = external_call["tsonic_node_fs_watch_next", OptionalPointer[NoneType, MutUntrackedOrigin]](handle)
            if not event:
                break
            did_work = True
            try:
                error = external_call["tsonic_node_fs_event_error", c_int](event.value())
                if error != 0:
                    watcher.close()
                    raise Error("Filesystem watch failed: ", error)
                var stat_listener = watcher._state[].stat
                var change_listener = watcher._state[].change
                if stat_listener:
                    stat_listener.value().call((_snapshot(event.value(), False), _snapshot(event.value(), True)))
                elif change_listener:
                    var length = c_size_t(0)
                    var name = external_call["tsonic_node_fs_event_filename", OptionalPointer[c_char, ImmutUntrackedOrigin]](event.value(), Pointer(to=length))
                    var filename = Optional[String]()
                    if name:
                        filename = String(from_utf8=Span(unsafe_ptr=name.value().unsafe_bitcast[Byte](), length=Int(length)))
                    var renamed = external_call["tsonic_node_fs_event_rename", c_int](event.value()) != 0
                    change_listener.value().call((String("rename" if renamed else "change"), filename))
            finally:
                external_call["tsonic_node_fs_event_free", NoneType](event.value())
    var retained = List[FSWatcher]()
    for watcher in _watchers.get()[]:
        if watcher._state[].handle:
            retained.append(watcher)
    _watchers.get()[] = retained^
    return did_work
