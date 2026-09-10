from std.collections import Dict, List
from tsonic_js.object import object_is
from tsonic_js.string import JsString
from tsonic_js.value import JsValue


struct _ComparisonFrame(Movable):
    var left: JsValue
    var right: JsValue
    var index: Int
    var length: Int
    var right_indexes: List[Int]

    def __init__(out self, left: JsValue, right: JsValue):
        self.left = left
        self.right = right
        self.index = -1
        self.length = 0
        self.right_indexes = List[Int]()


def deep_value_equal(left: JsValue, right: JsValue) raises -> Bool:
    var frames = List[_ComparisonFrame]()
    var active_left = Dict[UInt, Int]()
    var active_right = Dict[UInt, Int]()
    frames.append(_ComparisonFrame(left, right))
    while len(frames):
        var frame = frames.pop()
        if frame.index == -1:
            if object_is(frame.left, frame.right):
                continue
            if not frame.left.same_prototype(frame.right):
                return False
            if not frame.left.is_array() and not frame.left.is_object():
                return False
            if frame.left.is_byte_view():
                var left_bytes = frame.left.byte_view()
                var right_bytes = frame.right.byte_view()
                if left_bytes.length != right_bytes.length:
                    return False
                for index in range(left_bytes.length):
                    if left_bytes.storage[][left_bytes.offset + index] != right_bytes.storage[][right_bytes.offset + index]:
                        return False
                continue
            var left_position = active_left.get(frame.left._identity_address(), -1)
            var right_position = active_right.get(frame.right._identity_address(), -1)
            if left_position != -1 or right_position != -1:
                if left_position != right_position:
                    return False
                continue
            frame.length = frame.left._aggregate_length()
            if frame.length != frame.right._aggregate_length():
                return False
            if frame.left.is_object():
                var right_keys = Dict[JsString, Int]()
                for index in range(frame.length):
                    right_keys[frame.right._aggregate_key(index)] = index
                for index in range(frame.length):
                    var right_index = right_keys.get(frame.left._aggregate_key(index), -1)
                    if right_index == -1:
                        return False
                    frame.right_indexes.append(right_index)
            active_left[frame.left._identity_address()] = len(frames)
            active_right[frame.right._identity_address()] = len(frames)
            frame.index = 0
        if frame.index == frame.length:
            _ = active_left.pop(frame.left._identity_address())
            _ = active_right.pop(frame.right._identity_address())
            continue
        var index = frame.index
        frame.index += 1
        if frame.left.is_array():
            var left_present = frame.left._aggregate_has(index)
            if left_present != frame.right._aggregate_has(index):
                return False
            if not left_present:
                frames.append(frame^)
                continue
        var right_index = index if frame.left.is_array() else frame.right_indexes[index]
        var left_child = frame.left._aggregate_value(index)
        var right_child = frame.right._aggregate_value(right_index)
        frames.append(frame^)
        frames.append(_ComparisonFrame(left_child, right_child))
    return True
