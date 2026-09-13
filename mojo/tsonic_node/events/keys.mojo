from std.collections import List
from tsonic_js import JsString, JsValue


def validate_event(event: JsValue) raises:
    if not event.is_string() and not event.is_symbol():
        raise Error("Event name must be a string or symbol")


def is_error_event(event: JsValue) raises -> Bool:
    return event.is_string() and event.string_value() == JsString("error")


def event_index(event: JsValue) raises -> Optional[UInt32]:
    if not event.is_string():
        return None
    var text = event.string_value()
    var length = len(text)
    if length == 0 or length > 10:
        return None
    if length > 1 and text.code_unit_at(0).value() == 48:
        return None
    var result = UInt64(0)
    for index in range(length):
        var unit = text.code_unit_at(index).value()
        if unit < 48 or unit > 57:
            return None
        result = result * 10 + UInt64(unit - 48)
    if result >= 4294967295:
        return None
    return UInt32(result)


def ordered_event_names(events: List[JsValue]) raises -> List[JsValue]:
    var indexes = List[Tuple[UInt32, JsValue]]()
    var strings = List[JsValue]()
    var symbols = List[JsValue]()
    for event in events:
        var index = event_index(event)
        if index:
            var position = len(indexes)
            while position > 0 and indexes[position - 1][0] > index.value():
                position -= 1
            indexes.insert(position, (index.value(), event))
        elif event.is_string():
            strings.append(event)
        else:
            symbols.append(event)
    var result = List[JsValue](capacity=len(events))
    for entry in indexes:
        result.append(entry[1])
    result.extend(strings^)
    result.extend(symbols^)
    return result^
