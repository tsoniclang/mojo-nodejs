#include <brotli/decode.h>
#include <brotli/encode.h>
#include <zlib.h>

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define TSONIC_ZLIB_OUTPUT_LIMIT ((size_t)268435456u)

enum {
    TSONIC_ZLIB_DEFLATE = 1,
    TSONIC_ZLIB_INFLATE = 2,
    TSONIC_ZLIB_GZIP = 3,
    TSONIC_ZLIB_GUNZIP = 4,
    TSONIC_ZLIB_DEFLATE_RAW = 5,
    TSONIC_ZLIB_INFLATE_RAW = 6,
    TSONIC_ZLIB_UNZIP = 7,
    TSONIC_BROTLI_COMPRESS = 8,
    TSONIC_BROTLI_DECOMPRESS = 9
};

static char *copy_error(const char *message) {
    size_t length = strlen(message);
    char *copy = (char *)malloc(length + 1u);
    if (copy != NULL) {
        memcpy(copy, message, length + 1u);
    }
    return copy;
}

static int fail(char **error, const char *message) {
    if (error != NULL) {
        *error = copy_error(message);
    }
    return 0;
}

static size_t bounded_limit(size_t requested) {
    return requested == 0u || requested > TSONIC_ZLIB_OUTPUT_LIMIT
        ? TSONIC_ZLIB_OUTPUT_LIMIT
        : requested;
}

static int grow_buffer(
    uint8_t **buffer,
    size_t *capacity,
    size_t required,
    size_t limit,
    char **error
) {
    if (required > limit) {
        return fail(error, "Compression output exceeds maxOutputLength");
    }
    size_t next = *capacity == 0u ? 16384u : *capacity;
    while (next < required) {
        if (next > limit / 2u) {
            next = limit;
            break;
        }
        next *= 2u;
    }
    if (next < required) {
        return fail(error, "Compression output exceeds the finite runtime limit");
    }
    uint8_t *expanded = (uint8_t *)realloc(*buffer, next == 0u ? 1u : next);
    if (expanded == NULL) {
        return fail(error, "Unable to allocate compression output");
    }
    *buffer = expanded;
    *capacity = next;
    return 1;
}

static int zlib_window_bits(int32_t mode, int32_t configured) {
    if (configured != INT32_MIN) {
        int bits = configured < 0 ? -configured : configured;
        if (bits < 8 || bits > 15) {
            return 0;
        }
        if (mode == TSONIC_ZLIB_GZIP || mode == TSONIC_ZLIB_GUNZIP) {
            return bits + 16;
        }
        if (mode == TSONIC_ZLIB_DEFLATE_RAW || mode == TSONIC_ZLIB_INFLATE_RAW) {
            return -bits;
        }
        return bits;
    }
    if (mode == TSONIC_ZLIB_GZIP || mode == TSONIC_ZLIB_GUNZIP) {
        return 31;
    }
    if (mode == TSONIC_ZLIB_DEFLATE_RAW || mode == TSONIC_ZLIB_INFLATE_RAW) {
        return -15;
    }
    if (mode == TSONIC_ZLIB_UNZIP) {
        return 47;
    }
    return 15;
}

static int process_zlib(
    const uint8_t *input,
    size_t input_length,
    int32_t mode,
    int32_t level,
    int32_t window_bits,
    int32_t mem_level,
    int32_t strategy,
    size_t limit,
    const uint8_t *dictionary,
    size_t dictionary_length,
    uint8_t **output,
    size_t *output_length,
    char **error
) {
    if (input_length > UINT_MAX || dictionary_length > UINT_MAX) {
        return fail(error, "Compression input exceeds the native codec limit");
    }
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    int bits = zlib_window_bits(mode, window_bits);
    if (bits == 0) {
        return fail(error, "windowBits must have an absolute value from 8 through 15");
    }
    int compressing = mode == TSONIC_ZLIB_DEFLATE || mode == TSONIC_ZLIB_GZIP ||
        mode == TSONIC_ZLIB_DEFLATE_RAW;
    int status;
    if (compressing) {
        int selected_level = level == INT32_MIN ? Z_DEFAULT_COMPRESSION : level;
        int selected_memory = mem_level == INT32_MIN ? 8 : mem_level;
        int selected_strategy = strategy == INT32_MIN ? Z_DEFAULT_STRATEGY : strategy;
        status = deflateInit2(
            &stream,
            selected_level,
            Z_DEFLATED,
            bits,
            selected_memory,
            selected_strategy
        );
    } else {
        status = inflateInit2(&stream, bits);
    }
    if (status != Z_OK) {
        return fail(error, "Unable to initialize the selected compression codec");
    }
    if (dictionary_length != 0u) {
        status = compressing
            ? deflateSetDictionary(&stream, dictionary, (uInt)dictionary_length)
            : Z_OK;
        if (status != Z_OK) {
            if (compressing) {
                deflateEnd(&stream);
            } else {
                inflateEnd(&stream);
            }
            return fail(error, "Unable to apply the compression dictionary");
        }
    }
    uint8_t *buffer = NULL;
    size_t capacity = 0u;
    size_t produced = 0u;
    if (!grow_buffer(&buffer, &capacity, 1u, limit, error)) {
        if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
        return 0;
    }
    stream.next_in = (Bytef *)(uintptr_t)input;
    stream.avail_in = (uInt)input_length;
    for (;;) {
        if (produced == capacity &&
            !grow_buffer(&buffer, &capacity, produced + 1u, limit, error)) {
            free(buffer);
            if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
            return 0;
        }
        stream.next_out = buffer + produced;
        stream.avail_out = (uInt)((capacity - produced) > UINT_MAX
            ? UINT_MAX
            : (capacity - produced));
        status = compressing
            ? deflate(&stream, Z_FINISH)
            : inflate(&stream, Z_FINISH);
        produced = (size_t)stream.total_out;
        if (!compressing && status == Z_NEED_DICT && dictionary_length != 0u) {
            status = inflateSetDictionary(&stream, dictionary, (uInt)dictionary_length);
            if (status == Z_OK) continue;
        }
        if (status == Z_STREAM_END) break;
        if (status != Z_OK && status != Z_BUF_ERROR) {
            const char *message = stream.msg == NULL ? "Compression codec rejected its input" : stream.msg;
            free(buffer);
            if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
            return fail(error, message);
        }
        if (stream.avail_out != 0u && status == Z_BUF_ERROR) {
            free(buffer);
            if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
            return fail(error, "Compressed input ended before the stream was complete");
        }
        if (!grow_buffer(&buffer, &capacity, produced + 1u, limit, error)) {
            free(buffer);
            if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
            return 0;
        }
    }
    if (compressing) deflateEnd(&stream); else inflateEnd(&stream);
    *output = buffer;
    *output_length = produced;
    return 1;
}

static int process_brotli(
    const uint8_t *input,
    size_t input_length,
    int32_t mode,
    int32_t level,
    size_t limit,
    uint8_t **output,
    size_t *output_length,
    char **error
) {
    if (mode == TSONIC_BROTLI_COMPRESS) {
        size_t capacity = BrotliEncoderMaxCompressedSize(input_length);
        if (capacity == 0u || capacity > limit) {
            return fail(error, "Brotli output exceeds maxOutputLength");
        }
        uint8_t *buffer = (uint8_t *)malloc(capacity == 0u ? 1u : capacity);
        if (buffer == NULL) return fail(error, "Unable to allocate Brotli output");
        size_t produced = capacity;
        uint32_t quality = level == INT32_MIN ? BROTLI_DEFAULT_QUALITY : (uint32_t)level;
        if (quality > BROTLI_MAX_QUALITY || !BrotliEncoderCompress(
            quality,
            BROTLI_DEFAULT_WINDOW,
            BROTLI_MODE_GENERIC,
            input_length,
            input,
            &produced,
            buffer
        )) {
            free(buffer);
            return fail(error, "Brotli compression failed");
        }
        *output = buffer;
        *output_length = produced;
        return 1;
    }
    size_t capacity = input_length < 16384u ? 16384u : input_length * 2u;
    if (capacity > limit) capacity = limit;
    uint8_t *buffer = NULL;
    for (;;) {
        if (!grow_buffer(&buffer, &capacity, capacity == 0u ? 1u : capacity, limit, error)) {
            free(buffer);
            return 0;
        }
        size_t produced = capacity;
        BrotliDecoderResult status = BrotliDecoderDecompress(
            input_length,
            input,
            &produced,
            buffer
        );
        if (status == BROTLI_DECODER_RESULT_SUCCESS) {
            *output = buffer;
            *output_length = produced;
            return 1;
        }
        if (status != BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT || capacity == limit) {
            free(buffer);
            return fail(error, "Brotli decompression failed");
        }
        size_t next = capacity > limit / 2u ? limit : capacity * 2u;
        if (next <= capacity) {
            free(buffer);
            return fail(error, "Brotli output exceeds maxOutputLength");
        }
        capacity = next;
    }
}

int32_t tsonic_node_zlib_process(
    const uint8_t *input,
    size_t input_length,
    int32_t mode,
    int32_t level,
    int32_t window_bits,
    int32_t mem_level,
    int32_t strategy,
    size_t max_output_length,
    const uint8_t *dictionary,
    size_t dictionary_length,
    uint8_t **output,
    size_t *output_length,
    char **error
) {
    if (output == NULL || output_length == NULL || error == NULL ||
        (input_length != 0u && input == NULL) ||
        (dictionary_length != 0u && dictionary == NULL)) {
        return 0;
    }
    *output = NULL;
    *output_length = 0u;
    *error = NULL;
    size_t limit = bounded_limit(max_output_length);
    if (mode == TSONIC_BROTLI_COMPRESS || mode == TSONIC_BROTLI_DECOMPRESS) {
        return process_brotli(
            input,
            input_length,
            mode,
            level,
            limit,
            output,
            output_length,
            error
        );
    }
    if (mode < TSONIC_ZLIB_DEFLATE || mode > TSONIC_ZLIB_UNZIP) {
        return fail(error, "Unknown compression mode");
    }
    return process_zlib(
        input,
        input_length,
        mode,
        level,
        window_bits,
        mem_level,
        strategy,
        limit,
        dictionary,
        dictionary_length,
        output,
        output_length,
        error
    );
}
