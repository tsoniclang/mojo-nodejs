from .transform import Zlib
from ..buffer import Buffer
from ..internal.duplex import Duplex, create_duplex


def _read(mut stream: Zlib) raises -> Optional[Buffer]:
    return stream.read()


def _write(mut stream: Zlib, value: Buffer) raises -> Bool:
    return stream.write(value)


def _end(mut stream: Zlib, value: Optional[Buffer]) raises:
    if value:
        _ = stream.end_buffer(value.value())
    else:
        _ = stream.end()


def as_duplex(stream: Zlib) -> Duplex:
    return create_duplex(
        stream, UInt(Int(stream._state.unsafe_ptr())), _read, _write, _end
    )
