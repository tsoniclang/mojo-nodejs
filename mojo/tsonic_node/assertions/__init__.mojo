from tsonic_js.equality import same_value
from tsonic_js.value import JsValue
from .deep import deep_value_equal


def ok(value: Bool) raises:
    if not value:
        raise Error("Assertion failed")


def ok_with_message(value: Bool, message: String) raises:
    if not value:
        raise Error(message)


def strict_equal[T: Equatable](actual: T, expected: T) raises:
    if not same_value(actual, expected):
        raise Error("Values are not strictly equal")


def strict_equal_with_message[
    T: Equatable
](actual: T, expected: T, message: String) raises:
    if not same_value(actual, expected):
        raise Error(message)


def not_strict_equal[T: Equatable](actual: T, expected: T) raises:
    if same_value(actual, expected):
        raise Error("Values are strictly equal")


def not_strict_equal_with_message[
    T: Equatable
](actual: T, expected: T, message: String) raises:
    if same_value(actual, expected):
        raise Error(message)


def deep_strict_equal(actual: JsValue, expected: JsValue) raises:
    if not deep_value_equal(actual, expected):
        raise Error("Values are not deeply strictly equal")


def deep_strict_equal_with_message(actual: JsValue, expected: JsValue, message: String) raises:
    if not deep_value_equal(actual, expected):
        raise Error(message)
