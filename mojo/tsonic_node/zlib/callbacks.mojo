from tsonic_js import JsValue, js_value_error, js_value_from_null
from tsonic_runtime import RaisingCallable
from ..buffer import Buffer
from .options import ZlibOptions, BrotliOptions, CodecOptions
from .results import (
    ZlibInfo,
    ZlibResult,
    process_buffer,
    process_info,
    process_result,
)
from .notifications import pending_zlib


comptime ZlibCallback = RaisingCallable[
    Tuple[JsValue, Optional[Buffer]], NoneType
]
comptime ZlibInfoCallback = RaisingCallable[
    Tuple[JsValue, Optional[ZlibInfo]], NoneType
]
comptime ZlibResultCallback = RaisingCallable[
    Tuple[JsValue, Optional[ZlibResult]], NoneType
]


def enqueue(
    input: Buffer, mode: Int32, options: ZlibOptions, callback: ZlibCallback
) raises:
    _enqueue[Buffer](
        input, mode, CodecOptions(options), callback, process_buffer
    )


def enqueue(
    input: Buffer, mode: Int32, options: BrotliOptions, callback: ZlibCallback
) raises:
    _enqueue[Buffer](
        input, mode, CodecOptions(options.copy()), callback, process_buffer
    )


def enqueue_info(
    input: Buffer,
    mode: Int32,
    options: CodecOptions,
    callback: ZlibInfoCallback,
) raises:
    _enqueue[ZlibInfo](input, mode, options, callback, process_info)


def enqueue_result(
    input: Buffer,
    mode: Int32,
    options: CodecOptions,
    callback: ZlibResultCallback,
) raises:
    _enqueue[ZlibResult](input, mode, options, callback, process_result)


def _enqueue[
    Result: Copyable & Deinitable
](
    input: Buffer,
    mode: Int32,
    options: CodecOptions,
    callback: RaisingCallable[Tuple[JsValue, Optional[Result]], NoneType],
    operation: def(
        imm Buffer, imm Int32, imm CodecOptions
    ) thin raises -> Result,
) raises:
    pending_zlib.get()[].require_capacity()
    var output = Optional[Result]()
    var failure = js_value_from_null()
    try:
        output = operation(input, mode, options)
    except error:
        failure = js_value_error(String(error))
    pending_zlib.get()[].defer(callback, (failure, output^))
