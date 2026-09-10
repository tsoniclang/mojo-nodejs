from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from ..buffer import Buffer
from .native_options import create_native, raise_native_error
from .options import ZlibOptions, BrotliOptions, CodecOptions, finish_flush


struct NativeCodec(Movable):
    var handle: OptionalPointer[NoneType, MutUntrackedOrigin]
    var consumed: Int

    def __init__(out self, mode: Int32, options: CodecOptions) raises:
        self.handle = create_native(mode, options)
        self.consumed = 0

    def __deinit__(deinit self):
        if self.handle:
            external_call["tsonic_node_codec_free", NoneType](
                self.handle.value()
            )

    def close(mut self):
        if self.handle:
            external_call["tsonic_node_codec_free", NoneType](
                self.handle.value()
            )
            self.handle = None

    def write(mut self, input: Buffer, flush: Int32) raises -> Buffer:
        if not self.handle:
            raise Error("Compression engine is closed")
        var empty = Byte(0)
        var pointer = Pointer(to=empty).as_unsafe_any_origin()
        if len(input) != 0:
            pointer = (
                input._bytes[].unsafe_ptr() + input._offset
            ).as_unsafe_any_origin()
        var output = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var length = c_size_t(0)
        var consumed = c_size_t(0)
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var status = external_call["tsonic_node_codec_write", c_int](
            self.handle.value(),
            pointer,
            c_size_t(len(input)),
            c_int(flush),
            Pointer(to=output),
            Pointer(to=length),
            Pointer(to=consumed),
            Pointer(to=error),
        )
        self.consumed += Int(consumed)
        if status == 0:
            self.close()
        return take_output(status, output, Int(length), error)

    def params(mut self, level: Int32, strategy: Int32) raises -> Buffer:
        if not self.handle:
            raise Error("Compression engine is closed")
        var output = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var length = c_size_t(0)
        var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
        var status = external_call["tsonic_node_codec_params", c_int](
            self.handle.value(),
            c_int(level),
            c_int(strategy),
            Pointer(to=output),
            Pointer(to=length),
            Pointer(to=error),
        )
        if status == 0:
            self.close()
        return take_output(status, output, Int(length), error)


def process(input: Buffer, mode: Int32, options: CodecOptions) raises -> Buffer:
    var codec = NativeCodec(mode, options)
    return codec.write(input, finish_flush(options))


def process(input: Buffer, mode: Int32, options: ZlibOptions) raises -> Buffer:
    if options.info_value():
        raise Error("Compression info requires the engine/result contract")
    return process(input, mode, CodecOptions(options))


def process(
    input: Buffer, mode: Int32, options: BrotliOptions
) raises -> Buffer:
    if options.info_value():
        raise Error("Compression info requires the engine/result contract")
    return process(input, mode, CodecOptions(options.copy()))


def take_output(
    status: c_int,
    output: OptionalPointer[UInt8, MutUntrackedOrigin],
    length: Int,
    error: OptionalPointer[UInt8, MutUntrackedOrigin],
) raises -> Buffer:
    if status == 0 or not output:
        if output:
            external_call["tsonic_node_free", NoneType](output.value())
        raise_native_error(error)
    var bytes = List[Byte](capacity=length)
    for index in range(length):
        bytes.append(Byte(output.value()[unsafe_offset=index]))
    external_call["tsonic_node_free", NoneType](output.value())
    return Buffer(bytes^)
