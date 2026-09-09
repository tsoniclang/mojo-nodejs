from tsonic_js import JsValue, js_value_error, js_value_from_null
from tsonic_runtime import RaisingCallable, ErasedCallableContext, allocate_callable_environment, destroy_callable_environment
from ..buffer import Buffer
from .options import ZlibOptions, BrotliOptions, CodecOptions
from .results import ZlibInfo, ZlibResult, process_buffer, process_info, process_result


comptime ZlibCallback = RaisingCallable[Tuple[JsValue, Optional[Buffer]], NoneType]
comptime ZlibInfoCallback = RaisingCallable[Tuple[JsValue, Optional[ZlibInfo]], NoneType]
comptime ZlibResultCallback = RaisingCallable[Tuple[JsValue, Optional[ZlibResult]], NoneType]
from .notifications import Notification, MAX_PENDING, pending_count, defer_notification


@fieldwise_init
struct _Completion[Result: ImplicitlyCopyable]:
    var error: JsValue
    var output: Optional[Result]
    var callback: RaisingCallable[Tuple[JsValue, Optional[Result]], NoneType]

    @staticmethod
    def invoke(context: ErasedCallableContext, var _arguments: Tuple[]) raises:
        var completion = context.unsafe_bitcast[Self]()
        completion[].callback.call((completion[].error, completion[].output))

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[Self](context)


def enqueue(input: Buffer, mode: Int32, options: ZlibOptions, callback: ZlibCallback) raises:
    _enqueue[Buffer](input, mode, CodecOptions(options), callback, process_buffer)


def enqueue(input: Buffer, mode: Int32, options: BrotliOptions, callback: ZlibCallback) raises:
    _enqueue[Buffer](input, mode, CodecOptions(options.copy()), callback, process_buffer)


def enqueue_info(input: Buffer, mode: Int32, options: CodecOptions, callback: ZlibInfoCallback) raises:
    _enqueue[ZlibInfo](input, mode, options, callback, process_info)


def enqueue_result(input: Buffer, mode: Int32, options: CodecOptions, callback: ZlibResultCallback) raises:
    _enqueue[ZlibResult](input, mode, options, callback, process_result)


def _enqueue[Result: ImplicitlyCopyable](
    input: Buffer, mode: Int32, options: CodecOptions,
    callback: RaisingCallable[Tuple[JsValue, Optional[Result]], NoneType],
    operation: def(Buffer, Int32, CodecOptions) thin raises -> Result,
) raises:
    if pending_count() >= MAX_PENDING:
        raise Error("Pending compression callbacks exceed the finite runtime limit")
    var output = Optional[Result]()
    var failure = js_value_from_null()
    try:
        output = operation(input, mode, options)
    except error:
        failure = js_value_error(String(error))
    var environment = allocate_callable_environment(
        _Completion[Result](failure, output, callback), _Completion[Result].destroy,
    )
    defer_notification(Notification(environment, _Completion[Result].invoke))
