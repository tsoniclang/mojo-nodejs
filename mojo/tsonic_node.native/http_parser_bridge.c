#include <llhttp.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define HEADER_LIMIT (64u * 1024u)
#define BODY_LIMIT (256u * 1024u * 1024u)

typedef struct {
    llhttp_t parser;
    llhttp_settings_t settings;
    char *url;
    size_t url_length;
    size_t url_capacity;
    unsigned char *body;
    size_t body_length;
    size_t body_capacity;
    size_t header_bytes;
    size_t field_bytes;
    unsigned int delimiter;
    int headers_complete;
    int complete;
} HttpRequestParser;

static int append_bytes(void **buffer, size_t *length, size_t *capacity,
                        const char *bytes, size_t count, size_t limit) {
    if (count > limit - *length) return 0;
    size_t needed = *length + count + 1u;
    if (needed > *capacity) {
        size_t next = *capacity == 0u ? 256u : *capacity;
        while (next < needed) next = next > (limit + 1u) / 2u ? limit + 1u : next * 2u;
        void *grown = realloc(*buffer, next);
        if (grown == NULL) return 0;
        *buffer = grown;
        *capacity = next;
    }
    if (count != 0u) memcpy((char *)*buffer + *length, bytes, count);
    *length += count;
    ((char *)*buffer)[*length] = '\0';
    return 1;
}

static int receive_url(llhttp_t *parser, const char *bytes, size_t count) {
    HttpRequestParser *request = parser->data;
    if (!append_bytes((void **)&request->url, &request->url_length,
                      &request->url_capacity, bytes, count, HEADER_LIMIT)) {
        llhttp_set_error_reason(parser, "HTTP request target exceeds its byte budget or cannot be allocated");
        return HPE_USER;
    }
    return 0;
}

static int receive_field(llhttp_t *parser, const char *bytes, size_t count) {
    (void)bytes;
    HttpRequestParser *request = parser->data;
    if (count > HEADER_LIMIT - request->field_bytes) {
        llhttp_set_error_reason(parser, "HTTP header and trailer fields exceed their byte budget");
        return HPE_USER;
    }
    request->field_bytes += count;
    return 0;
}

static int receive_body(llhttp_t *parser, const char *bytes, size_t count) {
    HttpRequestParser *request = parser->data;
    if (!append_bytes((void **)&request->body, &request->body_length,
                      &request->body_capacity, bytes, count, BODY_LIMIT)) {
        llhttp_set_error_reason(parser, "HTTP request body exceeds its byte budget or cannot be allocated");
        return HPE_USER;
    }
    return 0;
}

static int complete_request(llhttp_t *parser) {
    HttpRequestParser *request = parser->data;
    request->complete = 1;
    return HPE_PAUSED;
}

void *tsonic_node_http_parser_new(void) {
    HttpRequestParser *request = calloc(1u, sizeof(*request));
    if (request == NULL) return NULL;
    llhttp_settings_init(&request->settings);
    request->settings.on_url = receive_url;
    request->settings.on_header_field = receive_field;
    request->settings.on_header_value = receive_field;
    request->settings.on_chunk_extension_name = receive_field;
    request->settings.on_chunk_extension_value = receive_field;
    request->settings.on_body = receive_body;
    request->settings.on_message_complete = complete_request;
    llhttp_init(&request->parser, HTTP_REQUEST, &request->settings);
    request->parser.data = request;
    return request;
}

void tsonic_node_http_parser_free(void *value) {
    HttpRequestParser *request = value;
    if (request == NULL) return;
    free(request->url);
    free(request->body);
    free(request);
}

int tsonic_node_http_parser_feed(void *value, const char *bytes, size_t count) {
    HttpRequestParser *request = value;
    if (request == NULL || (count != 0u && bytes == NULL)) return -1;
    if (request->complete) return 1;
    for (size_t index = 0; !request->headers_complete && index < count; index++) {
        if (++request->header_bytes > HEADER_LIMIT) {
            llhttp_set_error_reason(&request->parser, "HTTP request headers exceed their byte budget");
            return -1;
        }
        request->delimiter = (request->delimiter << 8u) | (unsigned char)bytes[index];
        if (request->delimiter == 0x0d0a0d0au) request->headers_complete = 1;
    }
    llhttp_errno_t result = llhttp_execute(&request->parser, bytes, count);
    if (request->complete && result == HPE_PAUSED) return 1;
    return result == HPE_OK ? 0 : -1;
}

const char *tsonic_node_http_parser_error(void *value) {
    HttpRequestParser *request = value;
    return request == NULL ? "HTTP request parser is absent" : llhttp_get_error_reason(&request->parser);
}

const char *tsonic_node_http_parser_method(void *value) {
    HttpRequestParser *request = value;
    return llhttp_method_name(llhttp_get_method(&request->parser));
}

const char *tsonic_node_http_parser_url(void *value) {
    HttpRequestParser *request = value;
    return request->url == NULL ? "" : request->url;
}

const unsigned char *tsonic_node_http_parser_body(void *value, size_t *length) {
    HttpRequestParser *request = value;
    *length = request->body_length;
    return request->body;
}
