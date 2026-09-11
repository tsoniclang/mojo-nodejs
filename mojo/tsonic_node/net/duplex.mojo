from .socket import Socket
from ..buffer import Buffer
from ..internal.duplex import Duplex, create_duplex


def _read(mut stream: Socket) raises -> Optional[Buffer]:
    return stream.read()


def _write(mut stream: Socket, value: Buffer) raises -> Bool:
    return stream.write_buffer(value)


def _end(mut stream: Socket, value: Optional[Buffer]) raises:
    if value:
        _ = stream.end_buffer(value.value())
    else:
        _ = stream.end()


def as_duplex(stream: Socket) -> Duplex:
    return create_duplex(
        stream, UInt(Int(stream._state.ptr())), _read, _write, _end
    )
