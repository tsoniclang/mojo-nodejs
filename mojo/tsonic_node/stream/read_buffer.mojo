from ..buffer import Buffer
from .byte_queue import ByteQueue
from .text_queue import TextQueue
from .decoder import StreamDecoder
from .chunk import StreamChunk


struct ReadBuffer(Movable):
    var _bytes: ByteQueue
    var _text: TextQueue
    var _decoder: Optional[StreamDecoder]
    var _finished: Bool

    def __init__(out self):
        self._bytes = ByteQueue()
        self._text = TextQueue()
        self._decoder = None
        self._finished = False

    def __len__(self) -> Int:
        return self._text.length if self._decoder else self._bytes.length

    def append(mut self, value: Buffer) raises:
        if self._finished:
            raise Error("Cannot append bytes after readable EOF")
        if self._decoder:
            self._text.append(self._decoder.value().write(value))
        else:
            self._bytes.append(value)

    def finish(mut self) raises:
        if self._finished:
            return
        if self._decoder:
            self._text.append(self._decoder.value().end())
        self._finished = True

    def set_encoding(mut self, name: String) raises:
        var decoder = StreamDecoder(name)
        while self._bytes.length:
            var bytes = self._bytes.take(self._bytes.length).value()
            self._text.append(decoder.write(bytes))
        if self._finished:
            self._text.append(decoder.end())
        self._decoder = Optional(decoder^)

    def clear(mut self):
        self._bytes.clear()
        self._text.clear()
        self._decoder = None

    def take(mut self, size: Int) raises -> Optional[StreamChunk]:
        if size == 0:
            return None
        if self._decoder:
            var text = self._text.take(size)
            return Optional(StreamChunk(text.value())) if text else Optional[StreamChunk]()
        var bytes = self._bytes.take(size)
        return Optional(StreamChunk(bytes.value())) if bytes else Optional[StreamChunk]()
