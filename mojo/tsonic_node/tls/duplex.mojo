from .socket import TLSSocket
from ..buffer import Buffer
from ..internal.duplex import Duplex, create_duplex


def _read(mut stream: TLSSocket) raises -> Optional[Buffer]:
    return stream.read()


def _write(mut stream: TLSSocket, value: Buffer) raises -> Bool:
    return stream.write_buffer(value)


def _end(mut stream: TLSSocket, value: Optional[Buffer]) raises:
    if value:
        _ = stream.end_buffer(value.value())
    else:
        _ = stream.end()


def as_duplex(stream: TLSSocket) -> Duplex:
    return create_duplex(stream, UInt(Int(stream._state.ptr())), _read, _write, _end)
