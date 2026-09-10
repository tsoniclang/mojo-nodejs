#include "output.h"
#include <limits.h>
#include <zlib.h>
#include <brotli/decode.h>
#include <brotli/encode.h>

typedef struct {
    int mode;
    int bits;
    int initialized;
    int finished;
    int failed;
    size_t maximum;
    size_t chunk_size;
    uint8_t *dictionary;
    size_t dictionary_length;
    z_stream zlib;
    gz_header header;
    BrotliEncoderState *encoder;
    BrotliDecoderState *decoder;
} TsonicCompression;

static int compressing(int mode) {
    return mode == 1 || mode == 3 || mode == 5 || mode == 8;
}

void tsonic_node_codec_free(void *handle) {
    TsonicCompression *codec = (TsonicCompression *)handle;
    if (codec == NULL) return;
    if (codec->initialized) {
        if (compressing(codec->mode)) deflateEnd(&codec->zlib);
        else inflateEnd(&codec->zlib);
    }
    if (codec->encoder != NULL) BrotliEncoderDestroyInstance(codec->encoder);
    if (codec->decoder != NULL) BrotliDecoderDestroyInstance(codec->decoder);
    free(codec->dictionary);
    free(codec);
}

static TsonicCompression *new_codec(int mode, size_t chunk_size, size_t maximum, char **error) {
    if (error == NULL) return NULL;
    *error = NULL;
    TsonicCodecOutput output;
    if (!codec_output_init(&output, maximum, chunk_size, error)) return NULL;
    TsonicCompression *codec = (TsonicCompression *)calloc(1u, sizeof(*codec));
    if (codec == NULL) {
        codec_fail(error, "Unable to allocate compression engine");
        return NULL;
    }
    codec->mode = mode;
    codec->maximum = maximum;
    codec->chunk_size = chunk_size;
    return codec;
}

void *tsonic_node_codec_zlib_new(
    int32_t mode, int32_t level, int32_t configured_window, int32_t memory, int32_t strategy,
    const uint8_t *dictionary, size_t dictionary_length,
    size_t chunk_size, size_t maximum, char **error
) {
    TsonicCompression *codec = new_codec(mode, chunk_size, maximum, error);
    if (codec == NULL) return NULL;
    int bits = configured_window == INT32_MIN ? 15 : configured_window;
    if (mode < 1 || mode > 7 || bits < 8 || bits > 15 ||
        dictionary_length > UINT_MAX || (dictionary == NULL && dictionary_length != 0u) ||
        (level != INT32_MIN && (level < -1 || level > 9)) ||
        (memory != INT32_MIN && (memory < 1 || memory > 9)) ||
        (strategy != INT32_MIN && (strategy < Z_DEFAULT_STRATEGY || strategy > Z_FIXED))) {
        codec_fail(error, "Invalid zlib codec option");
        goto fail;
    }
    if ((mode == 1 || mode == 5) && bits == 8) bits = 9;
    if (mode == 3 || mode == 4) bits += 16;
    else if (mode == 5 || mode == 6) bits = -bits;
    else if (mode == 7) bits += 32;
    codec->bits = bits;
    int status = compressing(mode)
        ? deflateInit2(&codec->zlib, level == INT32_MIN ? Z_DEFAULT_COMPRESSION : level,
            Z_DEFLATED, bits, memory == INT32_MIN ? 8 : memory,
            strategy == INT32_MIN ? Z_DEFAULT_STRATEGY : strategy)
        : inflateInit2(&codec->zlib, bits);
    if (status != Z_OK) {
        codec_fail(error, "Unable to initialize zlib engine");
        goto fail;
    }
    codec->initialized = 1;
    if (mode == 4 || mode == 7) inflateGetHeader(&codec->zlib, &codec->header);
    if (dictionary_length != 0u) {
        codec->dictionary = (uint8_t *)malloc(dictionary_length);
        if (codec->dictionary == NULL) {
            codec_fail(error, "Unable to retain compression dictionary");
            goto fail;
        }
        memcpy(codec->dictionary, dictionary, dictionary_length);
        codec->dictionary_length = dictionary_length;
        if (compressing(mode) || mode == 6) {
            status = compressing(mode)
                ? deflateSetDictionary(&codec->zlib, dictionary, (uInt)dictionary_length)
                : inflateSetDictionary(&codec->zlib, dictionary, (uInt)dictionary_length);
            if (status != Z_OK) {
                codec_fail(error, "Unable to apply compression dictionary");
                goto fail;
            }
        }
    }
    return codec;
fail:
    tsonic_node_codec_free(codec);
    return NULL;
}

void *tsonic_node_codec_brotli_new(
    int32_t mode, const uint32_t *parameter_ids, const uint32_t *parameter_values,
    size_t parameter_count, size_t chunk_size, size_t maximum, char **error
) {
    TsonicCompression *codec = new_codec(mode, chunk_size, maximum, error);
    if (codec == NULL) return NULL;
    if ((mode != 8 && mode != 9) ||
        (parameter_count != 0u && (parameter_ids == NULL || parameter_values == NULL))) {
        codec_fail(error, "Invalid Brotli engine or parameter array");
        goto fail;
    }
    if (mode == 8) codec->encoder = BrotliEncoderCreateInstance(NULL, NULL, NULL);
    else codec->decoder = BrotliDecoderCreateInstance(NULL, NULL, NULL);
    if (codec->encoder == NULL && codec->decoder == NULL) {
        codec_fail(error, "Unable to initialize Brotli engine");
        goto fail;
    }
    for (size_t index = 0; index < parameter_count; ++index) {
        BROTLI_BOOL accepted = codec->encoder != NULL
            ? BrotliEncoderSetParameter(codec->encoder, (BrotliEncoderParameter)parameter_ids[index], parameter_values[index])
            : BrotliDecoderSetParameter(codec->decoder, (BrotliDecoderParameter)parameter_ids[index], parameter_values[index]);
        if (!accepted) {
            codec_fail(error, "Brotli rejected an options.params entry");
            goto fail;
        }
    }
    return codec;
fail:
    tsonic_node_codec_free(codec);
    return NULL;
}

static int write_zlib(
    TsonicCompression *codec, const uint8_t *input, size_t length, int flush,
    TsonicCodecOutput *output, size_t *consumed, char **error
) {
    z_stream *stream = &codec->zlib;
    stream->next_in = (Bytef *)(uintptr_t)input;
    stream->avail_in = (uInt)length;
    for (;;) {
        uint8_t *target;
        size_t available;
        if (!codec_output_space(output, &target, &available, error)) return 0;
        if (codec->finished) {
            if (codec->header.done != 1 || stream->avail_in == 0u || *stream->next_in == 0) return 1;
            Bytef *remaining = stream->next_in;
            uInt remaining_length = stream->avail_in;
            if (inflateReset2(stream, codec->bits) != Z_OK) return codec_fail(error, "Unable to start the next gzip member");
            memset(&codec->header, 0, sizeof(codec->header));
            inflateGetHeader(stream, &codec->header);
            stream->next_in = remaining;
            stream->avail_in = remaining_length;
            codec->finished = 0;
        }
        stream->next_out = target;
        stream->avail_out = (uInt)available;
        uInt before = stream->avail_in;
        int status = compressing(codec->mode) ? deflate(stream, flush) : inflate(stream, flush);
        *consumed += before - stream->avail_in;
        size_t produced = available - stream->avail_out;
        if (!codec_output_advance(output, produced, error)) return 0;
        if (status == Z_NEED_DICT && codec->dictionary_length != 0u) {
            status = inflateSetDictionary(stream, codec->dictionary, (uInt)codec->dictionary_length);
            if (status == Z_OK) continue;
        }
        if (status == Z_STREAM_END) {
            codec->finished = 1;
            continue;
        }
        if (status != Z_OK && status != Z_BUF_ERROR) {
            return codec_fail(error, stream->msg == NULL ? "Compression codec rejected its input" : stream->msg);
        }
        if (flush != Z_FINISH && stream->avail_in == 0u && stream->avail_out != 0u) return 1;
        if (stream->avail_in == before && produced == 0u) {
            return codec_fail(error, "Compressed input ended before the stream was complete");
        }
    }
}

static int write_brotli(
    TsonicCompression *codec, const uint8_t *input, size_t length, int flush,
    TsonicCodecOutput *output, size_t *consumed, char **error
) {
    const uint8_t *next_input = input;
    size_t available_input = length;
    for (;;) {
        uint8_t *next_output;
        size_t available_output;
        if (!codec_output_space(output, &next_output, &available_output, error)) return 0;
        if (codec->finished) return 1;
        size_t before_input = available_input;
        size_t before_output = available_output;
        BrotliDecoderResult status = BROTLI_DECODER_RESULT_ERROR;
        if (codec->encoder != NULL) {
            if (!BrotliEncoderCompressStream(codec->encoder, (BrotliEncoderOperation)flush,
                &available_input, &next_input, &available_output, &next_output, NULL)) {
                return codec_fail(error, "Brotli compression failed");
            }
        } else {
            status = BrotliDecoderDecompressStream(codec->decoder, &available_input,
                &next_input, &available_output, &next_output, NULL);
        }
        *consumed += before_input - available_input;
        size_t produced = before_output - available_output;
        if (!codec_output_advance(output, produced, error)) return 0;
        if (codec->encoder != NULL) {
            codec->finished = BrotliEncoderIsFinished(codec->encoder);
            if (codec->finished || (flush != BROTLI_OPERATION_FINISH &&
                available_input == 0u && !BrotliEncoderHasMoreOutput(codec->encoder))) return 1;
        } else {
            codec->finished = status == BROTLI_DECODER_RESULT_SUCCESS;
            if (codec->finished || (status == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT &&
                available_input == 0u && flush != BROTLI_OPERATION_FINISH)) return 1;
            if (status == BROTLI_DECODER_RESULT_ERROR) {
                return codec_fail(error, BrotliDecoderErrorString(BrotliDecoderGetErrorCode(codec->decoder)));
            }
        }
        if (available_input == before_input && produced == 0u) {
            return codec_fail(error, "Brotli input ended before the stream was complete");
        }
    }
}

int32_t tsonic_node_codec_write(
    void *handle, const uint8_t *input, size_t length, int32_t flush,
    uint8_t **result, size_t *result_length, size_t *consumed, char **error
) {
    if (result == NULL || result_length == NULL || consumed == NULL || error == NULL) return 0;
    *result = NULL;
    *result_length = 0;
    *consumed = 0;
    *error = NULL;
    TsonicCompression *codec = (TsonicCompression *)handle;
    if (codec == NULL || codec->failed || length > UINT_MAX ||
        (input == NULL && length != 0u) || flush < 0 ||
        flush > (codec->mode < 8 ? Z_BLOCK : BROTLI_OPERATION_FINISH) ||
        (codec->finished && compressing(codec->mode) && length != 0u)) {
        return codec_fail(error, "Invalid compression write or closed engine");
    }
    TsonicCodecOutput output;
    if (!codec_output_init(&output, codec->maximum, codec->chunk_size, error)) return 0;
    int success = codec->mode < 8
        ? write_zlib(codec, input, length, flush, &output, consumed, error)
        : write_brotli(codec, input, length, flush, &output, consumed, error);
    if (!success) {
        codec->failed = 1;
        free(output.data);
        return 0;
    }
    *result = output.data;
    *result_length = output.size;
    return 1;
}

int32_t tsonic_node_codec_params(
    void *handle, int32_t level, int32_t strategy,
    uint8_t **result, size_t *result_length, char **error
) {
    if (error == NULL || result == NULL || result_length == NULL) return 0;
    *error = NULL;
    *result = NULL;
    *result_length = 0;
    TsonicCompression *codec = (TsonicCompression *)handle;
    if (codec == NULL || codec->failed || codec->finished || codec->mode >= 8 ||
        !compressing(codec->mode) || level < -1 || level > 9 || strategy < 0 || strategy > Z_FIXED) {
        return codec_fail(error, "Invalid compression parameter update");
    }
    TsonicCodecOutput output;
    if (!codec_output_init(&output, codec->maximum, codec->chunk_size, error)) return 0;
    codec->zlib.next_in = NULL;
    codec->zlib.avail_in = 0;
    for (;;) {
        uint8_t *target;
        size_t available;
        if (!codec_output_space(&output, &target, &available, error)) break;
        codec->zlib.next_out = target;
        codec->zlib.avail_out = (uInt)available;
        int status = deflateParams(&codec->zlib, level, strategy);
        if (!codec_output_advance(&output, available - codec->zlib.avail_out, error)) break;
        if (status == Z_OK) {
            *result = output.data;
            *result_length = output.size;
            return 1;
        }
        if (status != Z_BUF_ERROR || codec->zlib.avail_out != 0u) {
            codec_fail(error, "Unable to update compression parameters");
            break;
        }
    }
    codec->failed = 1;
    free(output.data);
    return 0;
}
