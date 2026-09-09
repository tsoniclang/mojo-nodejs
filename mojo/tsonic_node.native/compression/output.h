#ifndef TSONIC_NODE_COMPRESSION_OUTPUT_H
#define TSONIC_NODE_COMPRESSION_OUTPUT_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define TSONIC_CODEC_OUTPUT_LIMIT ((size_t)268435456u)

typedef struct {
    uint8_t *data;
    size_t size;
    size_t capacity;
    size_t limit;
    size_t chunk_size;
    uint8_t overflow;
} TsonicCodecOutput;

static int codec_fail(char **error, const char *message) {
    if (error != NULL) {
        size_t length = strlen(message);
        *error = (char *)malloc(length + 1u);
        if (*error != NULL) memcpy(*error, message, length + 1u);
    }
    return 0;
}

static int codec_output_init(
    TsonicCodecOutput *output, size_t limit, size_t chunk_size, char **error
) {
    memset(output, 0, sizeof(*output));
    if (limit == 0u || limit > TSONIC_CODEC_OUTPUT_LIMIT ||
        chunk_size < 64u || chunk_size > TSONIC_CODEC_OUTPUT_LIMIT) {
        return codec_fail(error, "Invalid compression output limit or chunk size");
    }
    output->limit = limit;
    output->chunk_size = chunk_size;
    return 1;
}

static int codec_output_space(
    TsonicCodecOutput *output, uint8_t **pointer, size_t *available, char **error
) {
    if (output->size == output->limit) {
        *pointer = &output->overflow;
        *available = 1u;
        return 1;
    }
    if (output->size == output->capacity) {
        size_t capacity = output->capacity == 0u
            ? output->chunk_size
            : output->capacity > output->limit / 2u
                ? output->limit : output->capacity * 2u;
        if (capacity > output->limit) capacity = output->limit;
        uint8_t *data = (uint8_t *)realloc(output->data, capacity);
        if (data == NULL) return codec_fail(error, "Unable to allocate compression output");
        output->data = data;
        output->capacity = capacity;
    }
    *pointer = output->data + output->size;
    *available = output->capacity - output->size;
    if (*available > output->chunk_size) *available = output->chunk_size;
    return 1;
}

static int codec_output_advance(TsonicCodecOutput *output, size_t count, char **error) {
    if (count > output->limit - output->size) {
        return codec_fail(error, "Compression output exceeds maxOutputLength");
    }
    output->size += count;
    return 1;
}

#endif
