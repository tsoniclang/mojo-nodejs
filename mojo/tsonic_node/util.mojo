from std.collections import List, Span

from .buffer import Buffer


struct TextDecoder(Copyable):
    var _encoding: String
    var _fatal: Bool
    var _ignore_bom: Bool

    def __init__(out self):
        self._encoding = "utf-8"
        self._fatal = False
        self._ignore_bom = False

    def __init__(out self, encoding: String) raises:
        var normalized = encoding.lower()
        if normalized != "utf8" and normalized != "utf-8":
            raise Error("Unsupported TextDecoder encoding: ", encoding)
        self._encoding = "utf-8"
        self._fatal = False
        self._ignore_bom = False

    def decode_empty(self) -> String:
        return String()

    def decode(self, input: Buffer) raises -> String:
        var bytes = input.copy_bytes()
        var first = 0
        if (
            not self._ignore_bom
            and len(bytes) >= 3
            and UInt8(bytes[0]) == 0xEF
            and UInt8(bytes[1]) == 0xBB
            and UInt8(bytes[2]) == 0xBF
        ):
            first = 3
        var decoded = List[Byte](capacity=len(bytes) - first)
        for index in range(first, len(bytes)):
            decoded.append(bytes[index])
        if self._fatal:
            return String(from_utf8=Span(decoded))
        return String(from_utf8_lossy=Span(decoded))

    def encoding(self) -> String:
        return self._encoding

    def fatal(self) -> Bool:
        return self._fatal

    def ignore_bom(self) -> Bool:
        return self._ignore_bom


def text_decoder_new() -> TextDecoder:
    return TextDecoder()


def text_decoder_new_encoding(encoding: String) raises -> TextDecoder:
    return TextDecoder(encoding)


def strip_vt_control_characters(value: String) -> String:
    var source = value.as_bytes()
    var output = List[Byte](capacity=len(source))
    var index = 0
    while index < len(source):
        if (
            UInt8(source[index]) == 0x1B
            and index + 1 < len(source)
            and UInt8(source[index + 1]) == 0x5B
        ):
            index += 2
            while index < len(source):
                var byte = UInt8(source[index])
                index += 1
                if byte >= 0x40 and byte <= 0x7E:
                    break
            continue
        output.append(source[index])
        index += 1
    return String(unsafe_from_utf8=Span(output))


def to_usv_string(value: String) -> String:
    return value


def style_text(style: String, text: String) raises -> String:
    var opening = _style_opening(style)
    var closing = _style_closing(style)
    return opening + text + closing


def _style_opening(style: String) raises -> String:
    if style == "reset":
        return "\x1b[0m"
    if style == "bold":
        return "\x1b[1m"
    if style == "dim":
        return "\x1b[2m"
    if style == "italic":
        return "\x1b[3m"
    if style == "underline":
        return "\x1b[4m"
    if style == "black":
        return "\x1b[30m"
    if style == "red":
        return "\x1b[31m"
    if style == "green":
        return "\x1b[32m"
    if style == "yellow":
        return "\x1b[33m"
    if style == "blue":
        return "\x1b[34m"
    if style == "magenta":
        return "\x1b[35m"
    if style == "cyan":
        return "\x1b[36m"
    if style == "white":
        return "\x1b[37m"
    raise Error("Unsupported util.styleText style: ", style)


def _style_closing(style: String) -> String:
    if style == "bold" or style == "dim":
        return "\x1b[22m"
    if style == "italic":
        return "\x1b[23m"
    if style == "underline":
        return "\x1b[24m"
    if style == "reset":
        return "\x1b[0m"
    return "\x1b[39m"
