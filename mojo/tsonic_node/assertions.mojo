from tsonic_js.equality import same_value


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
