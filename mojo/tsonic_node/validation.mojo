def checked_integer(
    value: Float64, maximum: Float64, name: String
) raises -> Int64:
    if not (value >= 0 and value <= maximum):
        raise Error("Invalid ", name)
    var result = Int64(value)
    if Float64(result) != value:
        raise Error(name, " must be an integer")
    return result
