from tsonic_js.number import number_is_integer, number_parse_int, number_to_string


def requested_read_size(value: Optional[Float64]) -> Optional[Float64]:
    if not value:
        return None
    var size = value.value()
    if number_is_integer(size):
        return size
    size = number_parse_int(number_to_string(size), 10)
    return size if size == size else Optional[Float64]()


def increased_read_threshold(size: Float64, current: Int) raises -> Int:
    if size <= Float64(current):
        return current
    if size > 1073741824:
        raise Error("Stream read size exceeds the 1 GiB growing threshold")
    var threshold = 1
    while Float64(threshold) < size:
        threshold *= 2
    return threshold
