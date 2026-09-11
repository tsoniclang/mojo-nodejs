from std.ffi import c_int, external_call, get_errno
from ..stream import Readable, Writable
from ..stream.descriptor import StreamDescriptor
from ..buffer.codec import encoding_name
from .descriptors import open_file
from .validation import checked_integer


@fieldwise_init
struct ReadStreamOptions(Copyable):
    var encoding: Optional[String]
    var flags: Optional[String]
    var mode: Optional[Float64]
    var start: Optional[Float64]
    var end: Optional[Float64]
    var high_water_mark: Optional[Float64]

    def __init__(out self):
        self.encoding = None
        self.flags = None
        self.mode = None
        self.start = None
        self.end = None
        self.high_water_mark = None


@fieldwise_init
struct WriteStreamOptions(Copyable):
    var encoding: Optional[String]
    var flags: Optional[String]
    var mode: Optional[Float64]
    var start: Optional[Float64]
    var high_water_mark: Optional[Float64]
    var flush: Optional[Bool]

    def __init__(out self):
        self.encoding = None
        self.flags = None
        self.mode = None
        self.start = None
        self.high_water_mark = None
        self.flush = None


def _position(value: Optional[Float64], name: String) raises -> Optional[Int64]:
    if not value:
        return None
    return checked_integer(value.value(), 9007199254740991.0, name)


def _open(
    path: String, flags: String, mode: Optional[Float64]
) raises -> StreamDescriptor:
    return StreamDescriptor(
        Int32(open_file(path, flags, mode.value() if mode else Float64(0o666))),
        True,
    )


def create_read_stream(path: String) raises -> Readable:
    return create_read_stream(path, ReadStreamOptions())


def create_read_stream(
    path: String, options: ReadStreamOptions
) raises -> Readable:
    var encoding = Optional(
        encoding_name(options.encoding.value())
    ) if options.encoding else Optional[String]()
    var start = _position(options.start, "start")
    var end = _position(options.end, "end")
    if Bool(start) and Bool(end) and start.value() > end.value():
        raise Error("File stream start exceeds end")
    var chunk_size = Int(
        checked_integer(
            options.high_water_mark.value(), 9007199254740991.0, "highWaterMark"
        )
    ) if options.high_water_mark else 65536
    var descriptor = _open(
        path,
        options.flags.value() if options.flags else String("r"),
        options.mode,
    )
    var result = Readable(descriptor, path, chunk_size, start, end, True)
    if encoding:
        _ = result.set_encoding(encoding.value())
    return result


def create_write_stream(path: String) raises -> Writable:
    return create_write_stream(path, WriteStreamOptions())


def create_write_stream(
    path: String, options: WriteStreamOptions
) raises -> Writable:
    var encoding = encoding_name(
        options.encoding.value()
    ) if options.encoding else String("utf8")
    var start = _position(options.start, "start")
    var high_water_mark = checked_integer(
        options.high_water_mark.value(), 9007199254740991.0, "highWaterMark"
    ) if options.high_water_mark else Int64(65536)
    var descriptor = _open(
        path,
        options.flags.value() if options.flags else String("w"),
        options.mode,
    )
    var result = Writable(
        descriptor,
        path,
        start,
        True,
        options.flush.value() if options.flush else False,
        high_water_mark,
    )
    result._state[].encoding = encoding
    return result
