from std.math import floor


def copy_offset(value: Float64) -> Int:
    if not (value >= -9007199254740991 and value <= 9007199254740991):
        return 0
    return Int(floor(value))


def clamp_offset(value: Float64, length: Int) -> Int:
    if value != value or value <= 0:
        return 0
    if value >= Float64(length):
        return length
    return Int(value)


def slice_offset(value: Float64, length: Int) -> Int:
    if value != value:
        return 0
    if value <= -Float64(length):
        return 0
    if value >= Float64(length):
        return length
    var index = Int(value)
    return length + index if index < 0 else index
