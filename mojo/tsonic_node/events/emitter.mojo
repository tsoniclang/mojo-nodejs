from std.collections import List
from std.memory import ArcPointer
from tsonic_js import JsValue, js_event_key_equal, js_value_to_string
from .callbacks import (
    EventCallback,
    Listener0,
    Listener1,
    Listener2,
    Listener3,
    ListenerRegistration,
    callback_identity,
    invoke_callback,
)
from .keys import is_error_event, ordered_event_names, validate_event


@fieldwise_init
struct EventGroup:
    var event: JsValue
    var listeners: List[ListenerRegistration]


@fieldwise_init
struct EventEmitterState:
    var groups: List[ArcPointer[EventGroup]]
    var max_listeners: Float64


struct EventEmitter(ImplicitlyCopyable):
    var _state: ArcPointer[EventEmitterState]

    def __init__(out self):
        self._state = ArcPointer(
            EventEmitterState(List[ArcPointer[EventGroup]](), 10.0)
        )

    def on_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, False)

    def on_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, False)

    def on_callable2(
        mut self, event: JsValue, callback: Listener2
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, False)

    def on_callable3(
        mut self, event: JsValue, callback: Listener3
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, False)

    def once_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, False)

    def once_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, False)

    def once_callable2(
        mut self, event: JsValue, callback: Listener2
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, False)

    def once_callable3(
        mut self, event: JsValue, callback: Listener3
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, False)

    def prepend_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, True)

    def prepend_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, True)

    def prepend_callable2(
        mut self, event: JsValue, callback: Listener2
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, True)

    def prepend_callable3(
        mut self, event: JsValue, callback: Listener3
    ) raises -> Self:
        return self._add(event, EventCallback(callback), False, True)

    def prepend_once_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, True)

    def prepend_once_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, True)

    def prepend_once_callable2(
        mut self, event: JsValue, callback: Listener2
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, True)

    def prepend_once_callable3(
        mut self, event: JsValue, callback: Listener3
    ) raises -> Self:
        return self._add(event, EventCallback(callback), True, True)

    def off_callable(
        mut self, event: JsValue, callback: Listener0
    ) raises -> Self:
        return self._remove(event, EventCallback(callback))

    def off_callable1(
        mut self, event: JsValue, callback: Listener1
    ) raises -> Self:
        return self._remove(event, EventCallback(callback))

    def off_callable2(
        mut self, event: JsValue, callback: Listener2
    ) raises -> Self:
        return self._remove(event, EventCallback(callback))

    def off_callable3(
        mut self, event: JsValue, callback: Listener3
    ) raises -> Self:
        return self._remove(event, EventCallback(callback))

    def emit_callable(mut self, event: JsValue) raises -> Bool:
        return self._emit(
            event,
            (JsValue.undefined(), JsValue.undefined(), JsValue.undefined()),
        )

    def emit_callable1(
        mut self, event: JsValue, value0: JsValue
    ) raises -> Bool:
        return self._emit(
            event, (value0, JsValue.undefined(), JsValue.undefined())
        )

    def emit_callable2(
        mut self, event: JsValue, value0: JsValue, value1: JsValue
    ) raises -> Bool:
        return self._emit(event, (value0, value1, JsValue.undefined()))

    def emit_callable3(
        mut self,
        event: JsValue,
        value0: JsValue,
        value1: JsValue,
        value2: JsValue,
    ) raises -> Bool:
        return self._emit(event, (value0, value1, value2))

    def listener_count(self, event: JsValue) raises -> Float64:
        validate_event(event)
        var group = self._find(event)
        return Float64(len(group.value()[].listeners)) if group else 0.0

    def event_names(self) raises -> List[JsValue]:
        var names = List[JsValue](capacity=len(self._state[].groups))
        for group in self._state[].groups:
            names.append(group[].event)
        return ordered_event_names(names)

    def get_max_listeners(self) -> Float64:
        return self._state[].max_listeners

    def set_max_listeners(mut self, count: Float64) raises -> Self:
        if count < 0 or count != count:
            raise Error(
                "EventEmitter max listeners must be a non-negative number"
            )
        self._state[].max_listeners = count
        return self

    def remove_all_listeners(mut self) -> Self:
        self._state[].groups.clear()
        return self

    def remove_all_listeners_for(mut self, event: JsValue) raises -> Self:
        validate_event(event)
        for index in range(len(self._state[].groups)):
            if js_event_key_equal(self._state[].groups[index][].event, event):
                _ = self._state[].groups.pop(index)
                break
        return self

    def _find(self, event: JsValue) -> Optional[ArcPointer[EventGroup]]:
        for group in self._state[].groups:
            if js_event_key_equal(group[].event, event):
                return group
        return None

    def _add(
        mut self,
        event: JsValue,
        callback: EventCallback,
        once: Bool,
        prepend: Bool,
    ) raises -> Self:
        validate_event(event)
        var selected = self._find(event)
        if not selected:
            selected = ArcPointer(
                EventGroup(event, List[ListenerRegistration]())
            )
            self._state[].groups.append(selected.value())
        var group = selected.value()
        var entry = ListenerRegistration(callback, once)
        if prepend:
            group[].listeners.insert(0, entry)
        else:
            group[].listeners.append(entry)
        return self

    def _remove(
        mut self, event: JsValue, callback: EventCallback
    ) raises -> Self:
        validate_event(event)
        var selected = self._find(event)
        if not selected:
            return self
        var group = selected.value()
        var identity = callback_identity(callback)
        var index = len(group[].listeners)
        while index > 0:
            index -= 1
            if callback_identity(group[].listeners[index].callback) is identity:
                _ = group[].listeners.pop(index)
                self._prune(group)
                break
        return self

    def _prune(mut self, group: ArcPointer[EventGroup]):
        if len(group[].listeners) != 0:
            return
        for index in range(len(self._state[].groups)):
            if self._state[].groups[index] is group:
                _ = self._state[].groups.pop(index)
                return

    def _emit(
        mut self, event: JsValue, values: Tuple[JsValue, JsValue, JsValue]
    ) raises -> Bool:
        validate_event(event)
        var selected = self._find(event)
        if not selected:
            if is_error_event(event):
                raise Error(
                    "Unhandled error event: "
                    + js_value_to_string(values[0]).to_native_strict()
                )
            return False
        var group = selected.value()
        var snapshot = group[].listeners.copy()
        for registration in snapshot:
            if registration.once:
                var consumed = registration.once.value()
                if consumed[]:
                    continue
                consumed[] = True
                for index in range(len(group[].listeners)):
                    var candidate = group[].listeners[index].once
                    if candidate and candidate.value() is consumed:
                        _ = group[].listeners.pop(index)
                        break
                self._prune(group)
            invoke_callback(registration.callback, values)
        return True


def event_emitter_new() -> EventEmitter:
    return EventEmitter()


def listener_count(emitter: EventEmitter, event: JsValue) raises -> Float64:
    return emitter.listener_count(event)
