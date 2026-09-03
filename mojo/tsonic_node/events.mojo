from std.collections import List
from std.memory import ArcPointer
from tsonic_js import JsValue, js_event_key_equal
from tsonic_runtime import RaisingCallable


alias Listener0 = RaisingCallable[Tuple[], NoneType]
alias Listener1 = RaisingCallable[Tuple[JsValue], NoneType]
alias Listener2 = RaisingCallable[Tuple[JsValue, JsValue], NoneType]
alias Listener3 = RaisingCallable[Tuple[JsValue, JsValue, JsValue], NoneType]


@fieldwise_init
struct _Listener0:
    var event: JsValue
    var callback: Listener0
    var once: Bool


@fieldwise_init
struct _Listener1:
    var event: JsValue
    var callback: Listener1
    var once: Bool


@fieldwise_init
struct _Listener2:
    var event: JsValue
    var callback: Listener2
    var once: Bool


@fieldwise_init
struct _Listener3:
    var event: JsValue
    var callback: Listener3
    var once: Bool


@fieldwise_init
struct _EventEmitterState:
    var listeners0: List[_Listener0]
    var listeners1: List[_Listener1]
    var listeners2: List[_Listener2]
    var listeners3: List[_Listener3]
    var max_listeners: Int


struct EventEmitter(ImplicitlyCopyable):
    var _state: ArcPointer[_EventEmitterState]

    def __init__(out self):
        self._state = ArcPointer(
            _EventEmitterState(
                List[_Listener0](),
                List[_Listener1](),
                List[_Listener2](),
                List[_Listener3](),
                10,
            )
        )

    def on_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        self._validate_event(event)
        self._state[].listeners0.append(_Listener0(event, callback, False))
        return self

    def on_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        self._validate_event(event)
        self._state[].listeners1.append(_Listener1(event, callback, False))
        return self

    def on_callable2(mut self, event: JsValue, callback: Listener2) raises -> Self:
        self._validate_event(event)
        self._state[].listeners2.append(_Listener2(event, callback, False))
        return self

    def on_callable3(mut self, event: JsValue, callback: Listener3) raises -> Self:
        self._validate_event(event)
        self._state[].listeners3.append(_Listener3(event, callback, False))
        return self

    def once_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        self._validate_event(event)
        self._state[].listeners0.append(_Listener0(event, callback, True))
        return self

    def once_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        self._validate_event(event)
        self._state[].listeners1.append(_Listener1(event, callback, True))
        return self

    def once_callable2(mut self, event: JsValue, callback: Listener2) raises -> Self:
        self._validate_event(event)
        self._state[].listeners2.append(_Listener2(event, callback, True))
        return self

    def once_callable3(mut self, event: JsValue, callback: Listener3) raises -> Self:
        self._validate_event(event)
        self._state[].listeners3.append(_Listener3(event, callback, True))
        return self

    def prepend_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        self._prepend0(_Listener0(event, callback, False))
        return self

    def prepend_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        self._prepend1(_Listener1(event, callback, False))
        return self

    def prepend_callable2(mut self, event: JsValue, callback: Listener2) raises -> Self:
        self._prepend2(_Listener2(event, callback, False))
        return self

    def prepend_callable3(mut self, event: JsValue, callback: Listener3) raises -> Self:
        self._prepend3(_Listener3(event, callback, False))
        return self

    def prepend_once_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        self._prepend0(_Listener0(event, callback, True))
        return self

    def prepend_once_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        self._prepend1(_Listener1(event, callback, True))
        return self

    def prepend_once_callable2(mut self, event: JsValue, callback: Listener2) raises -> Self:
        self._prepend2(_Listener2(event, callback, True))
        return self

    def prepend_once_callable3(mut self, event: JsValue, callback: Listener3) raises -> Self:
        self._prepend3(_Listener3(event, callback, True))
        return self

    def off_callable(mut self, event: JsValue, callback: Listener0) raises -> Self:
        self._validate_event(event)
        var next = List[_Listener0]()
        var removed = False
        for listener in self._state[].listeners0:
            if not removed and _same_event(listener.event, event) and listener.callback.same(callback):
                removed = True
            else:
                next.append(listener)
        self._state[].listeners0 = next^
        return self

    def off_callable1(mut self, event: JsValue, callback: Listener1) raises -> Self:
        self._validate_event(event)
        var next = List[_Listener1]()
        var removed = False
        for listener in self._state[].listeners1:
            if not removed and _same_event(listener.event, event) and listener.callback.same(callback):
                removed = True
            else:
                next.append(listener)
        self._state[].listeners1 = next^
        return self

    def off_callable2(mut self, event: JsValue, callback: Listener2) raises -> Self:
        self._validate_event(event)
        var next = List[_Listener2]()
        var removed = False
        for listener in self._state[].listeners2:
            if not removed and _same_event(listener.event, event) and listener.callback.same(callback):
                removed = True
            else:
                next.append(listener)
        self._state[].listeners2 = next^
        return self

    def off_callable3(mut self, event: JsValue, callback: Listener3) raises -> Self:
        self._validate_event(event)
        var next = List[_Listener3]()
        var removed = False
        for listener in self._state[].listeners3:
            if not removed and _same_event(listener.event, event) and listener.callback.same(callback):
                removed = True
            else:
                next.append(listener)
        self._state[].listeners3 = next^
        return self

    def emit_callable(mut self, event: JsValue) raises -> Bool:
        self._validate_event(event)
        var callbacks = List[Listener0]()
        var retained = List[_Listener0]()
        for listener in self._state[].listeners0:
            if _same_event(listener.event, event):
                callbacks.append(listener.callback)
                if not listener.once:
                    retained.append(listener)
            else:
                retained.append(listener)
        self._state[].listeners0 = retained^
        for callback in callbacks:
            callback.call(())
        return len(callbacks) != 0

    def emit_callable1(mut self, event: JsValue, value0: JsValue) raises -> Bool:
        self._validate_event(event)
        var callbacks = List[Listener1]()
        var retained = List[_Listener1]()
        for listener in self._state[].listeners1:
            if _same_event(listener.event, event):
                callbacks.append(listener.callback)
                if not listener.once:
                    retained.append(listener)
            else:
                retained.append(listener)
        self._state[].listeners1 = retained^
        for callback in callbacks:
            callback.call((value0,))
        return len(callbacks) != 0

    def emit_callable2(mut self, event: JsValue, value0: JsValue, value1: JsValue) raises -> Bool:
        self._validate_event(event)
        var callbacks = List[Listener2]()
        var retained = List[_Listener2]()
        for listener in self._state[].listeners2:
            if _same_event(listener.event, event):
                callbacks.append(listener.callback)
                if not listener.once:
                    retained.append(listener)
            else:
                retained.append(listener)
        self._state[].listeners2 = retained^
        for callback in callbacks:
            callback.call((value0, value1))
        return len(callbacks) != 0

    def emit_callable3(mut self, event: JsValue, value0: JsValue, value1: JsValue, value2: JsValue) raises -> Bool:
        self._validate_event(event)
        var callbacks = List[Listener3]()
        var retained = List[_Listener3]()
        for listener in self._state[].listeners3:
            if _same_event(listener.event, event):
                callbacks.append(listener.callback)
                if not listener.once:
                    retained.append(listener)
            else:
                retained.append(listener)
        self._state[].listeners3 = retained^
        for callback in callbacks:
            callback.call((value0, value1, value2))
        return len(callbacks) != 0

    def listener_count(self, event: JsValue) raises -> Float64:
        self._validate_event(event)
        var count = 0
        for listener in self._state[].listeners0:
            count += 1 if _same_event(listener.event, event) else 0
        for listener in self._state[].listeners1:
            count += 1 if _same_event(listener.event, event) else 0
        for listener in self._state[].listeners2:
            count += 1 if _same_event(listener.event, event) else 0
        for listener in self._state[].listeners3:
            count += 1 if _same_event(listener.event, event) else 0
        return Float64(count)

    def event_names(self) -> List[JsValue]:
        var result = List[JsValue]()
        for listener in self._state[].listeners0:
            _append_unique(result, listener.event)
        for listener in self._state[].listeners1:
            _append_unique(result, listener.event)
        for listener in self._state[].listeners2:
            _append_unique(result, listener.event)
        for listener in self._state[].listeners3:
            _append_unique(result, listener.event)
        return result^

    def get_max_listeners(self) -> Float64:
        return Float64(self._state[].max_listeners)

    def set_max_listeners(mut self, count: Float64) raises -> Self:
        if count < 0 or count != count or count == FloatLiteral.infinity:
            raise Error("EventEmitter max listeners must be a finite non-negative number")
        self._state[].max_listeners = Int(count)
        return self

    def remove_all_listeners(mut self) -> Self:
        self._state[].listeners0 = List[_Listener0]()
        self._state[].listeners1 = List[_Listener1]()
        self._state[].listeners2 = List[_Listener2]()
        self._state[].listeners3 = List[_Listener3]()
        return self

    def remove_all_listeners_for(mut self, event: JsValue) raises -> Self:
        self._validate_event(event)
        self._remove_event0(event)
        self._remove_event1(event)
        self._remove_event2(event)
        self._remove_event3(event)
        return self

    def _validate_event(self, event: JsValue) raises:
        if not event.is_string() and not event.is_symbol():
            raise Error("Event name must be a string or symbol")

    def _prepend0(mut self, listener: _Listener0) raises:
        self._validate_event(listener.event)
        var next = List[_Listener0]()
        next.append(listener)
        for current in self._state[].listeners0:
            next.append(current)
        self._state[].listeners0 = next^

    def _prepend1(mut self, listener: _Listener1) raises:
        self._validate_event(listener.event)
        var next = List[_Listener1]()
        next.append(listener)
        for current in self._state[].listeners1:
            next.append(current)
        self._state[].listeners1 = next^

    def _prepend2(mut self, listener: _Listener2) raises:
        self._validate_event(listener.event)
        var next = List[_Listener2]()
        next.append(listener)
        for current in self._state[].listeners2:
            next.append(current)
        self._state[].listeners2 = next^

    def _prepend3(mut self, listener: _Listener3) raises:
        self._validate_event(listener.event)
        var next = List[_Listener3]()
        next.append(listener)
        for current in self._state[].listeners3:
            next.append(current)
        self._state[].listeners3 = next^

    def _remove_event0(mut self, event: JsValue):
        var next = List[_Listener0]()
        for listener in self._state[].listeners0:
            if not _same_event(listener.event, event):
                next.append(listener)
        self._state[].listeners0 = next^

    def _remove_event1(mut self, event: JsValue):
        var next = List[_Listener1]()
        for listener in self._state[].listeners1:
            if not _same_event(listener.event, event):
                next.append(listener)
        self._state[].listeners1 = next^

    def _remove_event2(mut self, event: JsValue):
        var next = List[_Listener2]()
        for listener in self._state[].listeners2:
            if not _same_event(listener.event, event):
                next.append(listener)
        self._state[].listeners2 = next^

    def _remove_event3(mut self, event: JsValue):
        var next = List[_Listener3]()
        for listener in self._state[].listeners3:
            if not _same_event(listener.event, event):
                next.append(listener)
        self._state[].listeners3 = next^


def event_emitter_new() -> EventEmitter:
    return EventEmitter()


def listener_count(emitter: EventEmitter, event: JsValue) raises -> Float64:
    return emitter.listener_count(event)


def _same_event(left: JsValue, right: JsValue) -> Bool:
    return js_event_key_equal(left, right)


def _append_unique(mut values: List[JsValue], value: JsValue):
    for existing in values:
        if _same_event(existing, value):
            return
    values.append(value)
