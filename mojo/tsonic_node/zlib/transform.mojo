from std.collections import List
from std.memory import ArcPointer
from ..buffer import Buffer, buffer_concat
from ..validation import checked_integer
from .options import (
    ZlibOptions,
    BrotliOptions,
    CodecOptions,
    MAX_OUTPUT,
    optional_integer,
    finish_flush,
    write_flush,
)
from .codec import NativeCodec
from .notifications import Notification, defer_notification


struct _ZlibState(Movable):
    var mode: Int32
    var options: CodecOptions
    var codec: NativeCodec
    var output: List[Buffer]
    var output_bytes: Int
    var ended: Bool
    var destroyed: Bool

    def __init__(out self, mode: Int32, var options: CodecOptions) raises:
        self.mode = mode
        if options.isa[ZlibOptions]():
            var selected = options.unsafe_get[ZlibOptions]()
            if selected.dictionary:
                selected.dictionary = Buffer(
                    selected.dictionary.value().copy_bytes()
                )
            self.options = CodecOptions(selected)
        else:
            self.options = options^
        self.codec = NativeCodec(mode, self.options)
        self.output = List[Buffer]()
        self.output_bytes = 0
        self.ended = False
        self.destroyed = False


struct Zlib(ImplicitlyCopyable):
    var _state: ArcPointer[_ZlibState]

    def __init__(
        out self, mode: Int32, options: ZlibOptions = ZlibOptions()
    ) raises:
        self._state = ArcPointer(_ZlibState(mode, CodecOptions(options)))

    def __init__(out self, mode: Int32, options: BrotliOptions) raises:
        self._state = ArcPointer(_ZlibState(mode, CodecOptions(options.copy())))

    def write(self, input: Buffer) raises -> Bool:
        self._require_open()
        self._retain(
            self._state[].codec.write(input, write_flush(self._state[].options))
        )
        return True

    def write_string(self, input: String) raises -> Bool:
        return self.write(Buffer.from_string(input))

    def read(self) raises -> Optional[Buffer]:
        if self._state[].output_bytes == 0:
            return None
        var result = self._state[].output[0] if len(
            self._state[].output
        ) == 1 else buffer_concat(self._state[].output)
        self._state[].output = List[Buffer]()
        self._state[].output_bytes = 0
        return Optional(result)

    def end(self) raises -> Self:
        return self.end_buffer(Buffer())

    def end_buffer(self, input: Buffer) raises -> Self:
        if self._state[].ended:
            return self
        self._require_open()
        self._state[].ended = True
        self._retain(
            self._state[].codec.write(
                input, finish_flush(self._state[].options)
            )
        )
        self._state[].codec.close()
        return self

    def end_string(self, input: String) raises -> Self:
        return self.end_buffer(Buffer.from_string(input))

    def flush(self) raises:
        self.flush_kind(3.0 if self._state[].mode < 8 else 1.0)

    def flush_kind(self, kind: Float64) raises:
        self._require_open()
        var selected = checked_integer(
            kind, 5.0 if self._state[].mode < 8 else 2.0, "compression flush"
        )
        self._retain(self._state[].codec.write(Buffer(), Int32(selected)))

    def flush_callback(self, callback: Notification) raises:
        self.flush()
        defer_notification(callback)

    def flush_kind_callback(self, kind: Float64, callback: Notification) raises:
        self.flush_kind(kind)
        defer_notification(callback)

    def params(self, level: Float64, strategy: Float64) raises:
        self._require_open()
        self._retain(
            self._state[].codec.params(
                optional_integer(level), optional_integer(strategy)
            )
        )
        var options = self._state[].options.unsafe_get[ZlibOptions]()
        options.level = level
        options.strategy = strategy
        self._state[].options = CodecOptions(options)

    def params_callback(
        self, level: Float64, strategy: Float64, callback: Notification
    ) raises:
        self.params(level, strategy)
        defer_notification(callback)

    def reset(self) raises:
        self._require_open()
        self._state[].codec = NativeCodec(
            self._state[].mode, self._state[].options
        )

    def destroy(self):
        self._state[].destroyed = True
        self._state[].codec.close()
        self._state[].output = List[Buffer]()
        self._state[].output_bytes = 0

    def close(self):
        self.destroy()

    def close_callback(self, callback: Notification) raises:
        self.close()
        defer_notification(callback)

    def bytes_written(self) -> Float64:
        return Float64(self._state[].codec.consumed)

    def closed(self) -> Bool:
        return not self._state[].codec.handle

    def _require_open(self) raises:
        if (
            self._state[].ended
            or self._state[].destroyed
            or not self._state[].codec.handle
        ):
            raise Error("Compression engine is closed")

    def _retain(self, output: Buffer) raises:
        if len(output) > MAX_OUTPUT - self._state[].output_bytes:
            self.destroy()
            raise Error(
                "Pending compression output exceeds the finite runtime limit"
            )
        if len(output) != 0:
            self._state[].output.append(output)
            self._state[].output_bytes += len(output)
