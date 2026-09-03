from std.testing import assert_equal, assert_false, assert_true
from tsonic_js import JsValue
from tsonic_runtime import (
    ErasedCallableContext,
    Location,
    RaisingCallable,
    allocate_callable_environment,
    destroy_callable_environment,
)
from tsonic_node.buffer import Buffer
from tsonic_node.zlib import (
    ZlibOptions,
    brotli_compress_sync,
    brotli_decompress_sync,
    create_gzip,
    deflate_raw_sync,
    deflate_sync,
    gunzip_sync,
    gzip_callback,
    gzip_sync,
    gzip_sync_options,
    inflate_raw_sync,
    inflate_sync,
    poll_zlib,
    unzip_sync,
)


@fieldwise_init
struct CallbackEnvironment:
    var count: Location[Int]

    @staticmethod
    def invoke(
        context: ErasedCallableContext,
        var arguments: Tuple[JsValue, Buffer],
    ) raises:
        var environment = context.unsafe_bitcast[CallbackEnvironment]()
        assert_true(arguments[0].is_undefined())
        assert_true(len(arguments[1]) != 0)
        environment[].count.write(environment[].count.read() + 1)

    @staticmethod
    def destroy(context: ErasedCallableContext):
        destroy_callable_environment[CallbackEnvironment](context)


def callback(
    count: Location[Int],
) -> RaisingCallable[Tuple[JsValue, Buffer], NoneType]:
    var environment = allocate_callable_environment(
        CallbackEnvironment(count), CallbackEnvironment.destroy
    )
    return RaisingCallable[Tuple[JsValue, Buffer], NoneType](
        environment, CallbackEnvironment.invoke
    )


def main() raises:
    var input = Buffer.from_string("compression payload 😀")

    var gzip = gzip_sync(input)
    assert_equal(gunzip_sync(gzip).to_string(), input.to_string())
    assert_equal(unzip_sync(gzip).to_string(), input.to_string())

    var deflated = deflate_sync(input)
    assert_equal(inflate_sync(deflated).to_string(), input.to_string())

    var raw = deflate_raw_sync(input)
    assert_equal(inflate_raw_sync(raw).to_string(), input.to_string())

    var brotli = brotli_compress_sync(input)
    assert_equal(brotli_decompress_sync(brotli).to_string(), input.to_string())

    var options = ZlibOptions(
        level=Optional(1.0), max_output_length=Optional(4096.0)
    )
    assert_equal(
        gunzip_sync(gzip_sync_options(input, options)).to_string(),
        input.to_string(),
    )

    var stream = create_gzip()
    assert_true(stream.write(input))
    stream.end()
    var streamed = stream.read()
    assert_true(streamed)
    assert_false(stream.read())
    assert_equal(gunzip_sync(streamed.value()).to_string(), input.to_string())

    var count = Location(0)
    gzip_callback(input, callback(count))
    assert_true(poll_zlib())
    assert_equal(count.read(), 1)
    assert_false(poll_zlib())
