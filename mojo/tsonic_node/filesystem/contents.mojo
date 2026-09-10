from std.pathlib import Path
from ..buffer import Buffer, buffer_from_string_encoded
from ..buffer.codec import encoding_name
from ..stream.descriptor import StreamDescriptor
from .descriptors import open_file
from .validation import checked_path


def read_file(path: String) raises -> Buffer:
    checked_path(path)
    return Buffer(Path(path).read_bytes())


def read_text_file(path: String) raises -> String:
    return read_text_file_encoded(path, "utf8")


def read_text_file_encoded(path: String, encoding: String) raises -> String:
    var selected_encoding = encoding_name(encoding)
    return read_file(path).to_string(selected_encoding)


def _write(path: String, value: Buffer, flags: String) raises:
    var descriptor = StreamDescriptor(Int32(open_file(path, flags)), True)
    try:
        _ = descriptor.write(value, None)
    finally:
        descriptor.close()


def write_file(path: String, value: Buffer) raises:
    _write(path, value, "w")


def write_text_file(path: String, value: String, encoding: String = "utf8") raises:
    var buffer = buffer_from_string_encoded(value, encoding)
    write_file(path, buffer)


def append_file(path: String, value: Buffer) raises:
    _write(path, value, "a")


def append_text_file(path: String, value: String, encoding: String = "utf8") raises:
    var buffer = buffer_from_string_encoded(value, encoding)
    append_file(path, buffer)
