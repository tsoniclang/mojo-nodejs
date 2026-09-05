from std.collections import List
from std.ffi import c_int, c_size_t, external_call
from std.memory import ArcPointer
from tsonic_js import JsValue, js_value_error, js_value_from_undefined
from tsonic_runtime import GlobalCell, RaisingCallable

from .buffer import Buffer


comptime ZlibCallback = RaisingCallable[Tuple[JsValue, Buffer], NoneType]

comptime _DEFLATE = Int32(1)
comptime _INFLATE = Int32(2)
comptime _GZIP = Int32(3)
comptime _GUNZIP = Int32(4)
comptime _DEFLATE_RAW = Int32(5)
comptime _INFLATE_RAW = Int32(6)
comptime _UNZIP = Int32(7)
comptime _BROTLI_COMPRESS = Int32(8)
comptime _BROTLI_DECOMPRESS = Int32(9)
comptime _UNSET = Int32(-2147483648)
comptime _MAX_OUTPUT = 268_435_456
comptime _MAX_PENDING = 1 << 20


struct ZlibOptions(ImplicitlyCopyable):
    var flush: Optional[Float64]
    var finish_flush: Optional[Float64]
    var chunk_size: Optional[Float64]
    var window_bits: Optional[Float64]
    var level: Optional[Float64]
    var mem_level: Optional[Float64]
    var strategy: Optional[Float64]
    var max_output_length: Optional[Float64]
    var dictionary: Optional[Buffer]
    var info: Optional[Bool]

    def __init__(
        out self,
        flush: Optional[Float64] = None,
        finish_flush: Optional[Float64] = None,
        chunk_size: Optional[Float64] = None,
        window_bits: Optional[Float64] = None,
        level: Optional[Float64] = None,
        mem_level: Optional[Float64] = None,
        strategy: Optional[Float64] = None,
        max_output_length: Optional[Float64] = None,
        dictionary: Optional[Buffer] = None,
        info: Optional[Bool] = None,
    ):
        self.flush = flush
        self.finish_flush = finish_flush
        self.chunk_size = chunk_size
        self.window_bits = window_bits
        self.level = level
        self.mem_level = mem_level
        self.strategy = strategy
        self.max_output_length = max_output_length
        self.dictionary = dictionary
        self.info = info


struct _ZlibState:
    var mode: Int32
    var options: ZlibOptions
    var input: ArcPointer[List[Byte]]
    var output: Optional[Buffer]
    var ended: Bool

    def __init__(out self, mode: Int32, options: ZlibOptions):
        self.mode = mode
        self.options = options
        self.input = ArcPointer(List[Byte]())
        self.output = None
        self.ended = False


struct Zlib(ImplicitlyCopyable):
    var _state: ArcPointer[_ZlibState]

    def __init__(out self, mode: Int32, options: ZlibOptions = ZlibOptions()):
        self._state = ArcPointer(_ZlibState(mode, options))

    def write(self, input: Buffer) raises -> Bool:
        if self._state[].ended:
            raise Error("write after end")
        if len(self._state[].input[]) + len(input) > _MAX_OUTPUT:
            raise Error(
                "Pending compression input exceeds the finite runtime limit"
            )
        for value in input.copy_bytes():
            self._state[].input[].append(value)
        return True

    def read(self) -> Optional[Buffer]:
        if not self._state[].output:
            return None
        return Optional(self._state[].output.take())

    def end(self) raises:
        if self._state[].ended:
            return
        self._state[].ended = True
        var input_length = len(self._state[].input[])
        var input = Buffer(self._state[].input, 0, input_length)
        self._state[].input = ArcPointer(List[Byte]())
        self._state[].output = Optional(
            _process(input, self._state[].mode, self._state[].options)
        )


@fieldwise_init
struct _PendingZlib(ImplicitlyCopyable):
    var error: JsValue
    var output: Buffer
    var callback: ZlibCallback


def _initial_pending() -> List[_PendingZlib]:
    return List[_PendingZlib]()


comptime _pending = GlobalCell["tsonic.node.zlib.pending", _initial_pending]()


def gzip_sync(input: Buffer) raises -> Buffer:
    return _process(input, _GZIP, ZlibOptions())


def gzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return _process(input, _GZIP, options)


def gunzip_sync(input: Buffer) raises -> Buffer:
    return _process(input, _GUNZIP, ZlibOptions())


def gunzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return _process(input, _GUNZIP, options)


def deflate_sync(input: Buffer) raises -> Buffer:
    return _process(input, _DEFLATE, ZlibOptions())


def deflate_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return _process(input, _DEFLATE, options)


def inflate_sync(input: Buffer) raises -> Buffer:
    return _process(input, _INFLATE, ZlibOptions())


def inflate_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return _process(input, _INFLATE, options)


def deflate_raw_sync(input: Buffer) raises -> Buffer:
    return _process(input, _DEFLATE_RAW, ZlibOptions())


def deflate_raw_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return _process(input, _DEFLATE_RAW, options)


def inflate_raw_sync(input: Buffer) raises -> Buffer:
    return _process(input, _INFLATE_RAW, ZlibOptions())


def inflate_raw_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return _process(input, _INFLATE_RAW, options)


def unzip_sync(input: Buffer) raises -> Buffer:
    return _process(input, _UNZIP, ZlibOptions())


def unzip_sync_options(input: Buffer, options: ZlibOptions) raises -> Buffer:
    return _process(input, _UNZIP, options)


def brotli_compress_sync(input: Buffer) raises -> Buffer:
    return _process(input, _BROTLI_COMPRESS, ZlibOptions())


def brotli_compress_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return _process(input, _BROTLI_COMPRESS, options)


def brotli_decompress_sync(input: Buffer) raises -> Buffer:
    return _process(input, _BROTLI_DECOMPRESS, ZlibOptions())


def brotli_decompress_sync_options(
    input: Buffer, options: ZlibOptions
) raises -> Buffer:
    return _process(input, _BROTLI_DECOMPRESS, options)


def gzip_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _GZIP, ZlibOptions(), callback)


def gzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _GZIP, options, callback)


def gunzip_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _GUNZIP, ZlibOptions(), callback)


def gunzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _GUNZIP, options, callback)


def deflate_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _DEFLATE, ZlibOptions(), callback)


def deflate_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _DEFLATE, options, callback)


def inflate_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _INFLATE, ZlibOptions(), callback)


def inflate_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _INFLATE, options, callback)


def deflate_raw_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _DEFLATE_RAW, ZlibOptions(), callback)


def deflate_raw_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _DEFLATE_RAW, options, callback)


def inflate_raw_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _INFLATE_RAW, ZlibOptions(), callback)


def inflate_raw_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _INFLATE_RAW, options, callback)


def unzip_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _UNZIP, ZlibOptions(), callback)


def unzip_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _UNZIP, options, callback)


def brotli_compress_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _BROTLI_COMPRESS, ZlibOptions(), callback)


def brotli_compress_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _BROTLI_COMPRESS, options, callback)


def brotli_decompress_callback(input: Buffer, callback: ZlibCallback) raises:
    _enqueue(input, _BROTLI_DECOMPRESS, ZlibOptions(), callback)


def brotli_decompress_callback_options(
    input: Buffer, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue(input, _BROTLI_DECOMPRESS, options, callback)


def create_gzip() -> Zlib:
    return Zlib(_GZIP)


def create_gzip_options(options: ZlibOptions) -> Zlib:
    return Zlib(_GZIP, options)


def create_gunzip() -> Zlib:
    return Zlib(_GUNZIP)


def create_gunzip_options(options: ZlibOptions) -> Zlib:
    return Zlib(_GUNZIP, options)


def create_deflate() -> Zlib:
    return Zlib(_DEFLATE)


def create_deflate_options(options: ZlibOptions) -> Zlib:
    return Zlib(_DEFLATE, options)


def create_inflate() -> Zlib:
    return Zlib(_INFLATE)


def create_inflate_options(options: ZlibOptions) -> Zlib:
    return Zlib(_INFLATE, options)


def create_deflate_raw() -> Zlib:
    return Zlib(_DEFLATE_RAW)


def create_deflate_raw_options(options: ZlibOptions) -> Zlib:
    return Zlib(_DEFLATE_RAW, options)


def create_inflate_raw() -> Zlib:
    return Zlib(_INFLATE_RAW)


def create_inflate_raw_options(options: ZlibOptions) -> Zlib:
    return Zlib(_INFLATE_RAW, options)


def has_pending_zlib() -> Bool:
    return len(_pending.get()[]) != 0


def poll_zlib() raises -> Bool:
    if len(_pending.get()[]) == 0:
        return False
    var pending = List[_PendingZlib]()
    for value in _pending.get()[]:
        pending.append(value)
    _pending.get()[] = List[_PendingZlib]()
    for value in pending:
        value.callback.call((value.error, value.output))
    return True


def _enqueue(
    input: Buffer,
    mode: Int32,
    options: ZlibOptions,
    callback: ZlibCallback,
) raises:
    if len(_pending.get()[]) >= _MAX_PENDING:
        raise Error(
            "Pending compression callbacks exceed the finite runtime limit"
        )
    try:
        var output = _process(input, mode, options)
        _pending.get()[].append(
            _PendingZlib(js_value_from_undefined(), output, callback)
        )
    except error:
        _pending.get()[].append(
            _PendingZlib(js_value_error(String(error)), Buffer(), callback)
        )


def _process(input: Buffer, mode: Int32, options: ZlibOptions) raises -> Buffer:
    var input_bytes = input.copy_bytes()
    if len(input_bytes) == 0:
        input_bytes.append(Byte(0))
    var dictionary = (
        options.dictionary.value().copy_bytes() if options.dictionary else List[
            Byte
        ]()
    )
    var dictionary_length = len(dictionary)
    if dictionary_length == 0:
        dictionary.append(Byte(0))
    var output = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var output_length = c_size_t(0)
    var error = OptionalPointer[UInt8, MutUntrackedOrigin]()
    var status = external_call["tsonic_node_zlib_process", c_int](
        input_bytes.unsafe_ptr(),
        c_size_t(len(input)),
        c_int(mode),
        c_int(_optional_int(options.level)),
        c_int(_optional_int(options.window_bits)),
        c_int(_optional_int(options.mem_level)),
        c_int(_optional_int(options.strategy)),
        c_size_t(_max_output(options.max_output_length)),
        dictionary.unsafe_ptr(),
        c_size_t(dictionary_length),
        Pointer(to=output),
        Pointer(to=output_length),
        Pointer(to=error),
    )
    if status == 0 or not output:
        raise Error(_take_error(error, "Compression operation failed"))
    var bytes = List[Byte](capacity=Int(output_length))
    for index in range(Int(output_length)):
        bytes.append(Byte(output.value()[unsafe_offset=index]))
    external_call["tsonic_node_free", NoneType](output.value())
    return Buffer(bytes^)


def _optional_int(value: Optional[Float64]) raises -> Int32:
    if not value:
        return _UNSET
    var integer = Int(value.value())
    if (
        Float64(integer) != value.value()
        or integer < -2147483647
        or integer > 2147483647
    ):
        raise Error("Compression option must be a finite 32-bit integer")
    return Int32(integer)


def _max_output(value: Optional[Float64]) raises -> Int:
    if not value:
        return _MAX_OUTPUT
    var integer = Int(value.value())
    if (
        Float64(integer) != value.value()
        or integer < 0
        or integer > _MAX_OUTPUT
    ):
        raise Error(
            "maxOutputLength must be a finite integer within the runtime limit"
        )
    return integer


def _take_error(
    pointer: OptionalPointer[UInt8, MutUntrackedOrigin],
    fallback: String,
) -> String:
    if not pointer:
        return fallback
    var value = String(unsafe_from_utf8_ptr=pointer.value())
    external_call["tsonic_node_free", NoneType](pointer.value())
    return value^
