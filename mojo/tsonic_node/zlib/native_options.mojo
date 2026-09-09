from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from ..validation import checked_integer
from .options import ZlibOptions, BrotliOptions, CodecOptions, optional_integer, output_limit, chunk_size, validate_flush


def create_native(mode: Int32, options: CodecOptions) raises -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    if options.isa[ZlibOptions]():
        return create_native(mode, options.unsafe_get[ZlibOptions]())
    return create_native(mode, options.unsafe_get[BrotliOptions]())


def create_native(mode: Int32, options: ZlibOptions) raises -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    validate_flush(options.flush, 5)
    validate_flush(options.finish_flush, 5)
    var dictionary = options.dictionary.value().copy_bytes() if options.dictionary else List[Byte]()
    var dictionary_length = len(dictionary)
    if dictionary_length == 0:
        dictionary.append(Byte(0))
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call["tsonic_node_codec_zlib_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
        c_int(mode), c_int(optional_integer(options.level)), c_int(optional_integer(options.window_bits)),
        c_int(optional_integer(options.mem_level)), c_int(optional_integer(options.strategy)),
        dictionary.unsafe_ptr(), c_size_t(dictionary_length),
        c_size_t(chunk_size(options.chunk_size)), c_size_t(output_limit(options.max_output_length)), Pointer(to=error),
    )
    if not handle:
        raise_native_error(error)
    return handle


def create_native(mode: Int32, options: BrotliOptions) raises -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    validate_flush(options.flush, 2)
    validate_flush(options.finish_flush, 2)
    var identifiers = List[UInt32]()
    var values = List[UInt32]()
    if options.params:
        for key, value in options.params.value().items():
            identifiers.append(UInt32(checked_integer(key, 4294967295, "Brotli parameter id")))
            var numeric = Float64(value.unsafe_get[Bool]()) if value.isa[Bool]() else value.unsafe_get[Float64]()
            values.append(UInt32(checked_integer(numeric, 4294967295, "Brotli parameter value")))
    var count = len(identifiers)
    if count == 0:
        identifiers.append(0)
        values.append(0)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var handle = external_call["tsonic_node_codec_brotli_new", OptionalPointer[NoneType, MutUntrackedOrigin]](
        c_int(mode), identifiers.unsafe_ptr(), values.unsafe_ptr(), c_size_t(count),
        c_size_t(chunk_size(options.chunk_size)), c_size_t(output_limit(options.max_output_length)), Pointer(to=error),
    )
    if not handle:
        raise_native_error(error)
    return handle


def raise_native_error(error: OptionalPointer[UInt8, MutUntrackedOrigin]) raises:
    var message = String("Compression operation failed")
    if error:
        message = String(unsafe_from_utf8_ptr=error.value())
        external_call["tsonic_node_free", NoneType](error.value())
    raise Error(message)
