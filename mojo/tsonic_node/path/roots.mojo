@fieldwise_init
struct WindowsRoot(Copyable):
    var device: String
    var tail_start: Int
    var display_end: Int
    var absolute: Bool
    var reserved: Bool


def is_separator(byte: Byte) -> Bool:
    return byte == 47 or byte == 92


def is_drive(byte: Byte) -> Bool:
    return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)


def reserved_device(name: String) -> Bool:
    var value = name.upper()
    if value == "CON" or value == "PRN" or value == "AUX" or value == "NUL":
        return True
    if value.startswith("COM") or value.startswith("LPT"):
        var suffix = String(value[byte=3:])
        if suffix == "¹" or suffix == "²" or suffix == "³":
            return True
        return suffix.byte_length() == 1 and suffix.as_bytes()[0] >= 49 and suffix.as_bytes()[0] <= 57
    return False


def windows_root(path: String, normalization: Bool = False) -> WindowsRoot:
    var result = WindowsRoot("", 0, 0, False, False)
    var length = path.byte_length()
    if length == 0:
        return result^
    var bytes = path.as_bytes()
    if is_separator(bytes[0]):
        result.absolute = True
        result.tail_start = 1
        result.display_end = 1
        if length < 2 or not is_separator(bytes[1]):
            return result^
        var host_end = 2
        while host_end < length and not is_separator(bytes[host_end]):
            host_end += 1
        if host_end == 2 or host_end == length:
            return result^
        var share_start = host_end
        while share_start < length and is_separator(bytes[share_start]):
            share_start += 1
        var share_end = share_start
        while share_end < length and not is_separator(bytes[share_end]):
            share_end += 1
        if share_end == share_start:
            return result^
        var host = String(path[byte=2:host_end])
        var share = String(path[byte=share_start:share_end])
        result.display_end = share_end + 1 if share_end < length else share_end
        if normalization and (host == "?" or host == "."):
            result.device = "\\\\" + host
            result.tail_start = 4
            var colon = share.find(":")
            if colon > 0 and reserved_device(String(share[byte=:colon])):
                result.device = "\\\\?\\" + String(share[byte=:colon + 1])
                result.tail_start = share_start + colon + 1
        else:
            result.device = "\\\\" + host + "\\" + share
            result.tail_start = share_end
        return result^
    if length >= 2 and is_drive(bytes[0]) and bytes[1] == 58:
        result.device = String(path[byte=:2])
        result.tail_start = 2
        result.display_end = 2
        if length > 2 and is_separator(bytes[2]):
            result.absolute = True
            result.tail_start = 3
            result.display_end = 3
    elif normalization:
        var colon = path.find(":")
        if colon > 0 and reserved_device(String(path[byte=:colon])):
            result.device = String(path[byte=:colon + 1])
            result.tail_start = colon + 1
            result.reserved = True
    return result^
