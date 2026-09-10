#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static atomic_uint live_requests;

TsonicDnsRequest *tsonic_dns_request_new(const char *input, int kind) {
    if (input == NULL || strlen(input) > 4096) return NULL;
    unsigned count = atomic_fetch_add_explicit(&live_requests, 1, memory_order_relaxed);
    if (count >= TSONIC_DNS_REQUEST_LIMIT) {
        atomic_fetch_sub_explicit(&live_requests, 1, memory_order_relaxed);
        return NULL;
    }
    TsonicDnsRequest *request = calloc(1, sizeof(*request));
    if (request == NULL) {
        atomic_fetch_sub_explicit(&live_requests, 1, memory_order_relaxed);
        return NULL;
    }
    atomic_init(&request->references, 2);
    atomic_init(&request->ready, 0);
    request->kind = kind;
    request->input = strdup(input);
    if (request->input == NULL) {
        free(request);
        atomic_fetch_sub_explicit(&live_requests, 1, memory_order_relaxed);
        return NULL;
    }
    return request;
}

int tsonic_dns_result_append(TsonicDnsRequest *request, const char *value) {
    if (value == NULL || request->failed) return 0;
    size_t size = strlen(value) + 1;
    if (request->count >= TSONIC_DNS_RESULT_LIMIT || size > TSONIC_DNS_BYTE_LIMIT - request->bytes) {
        tsonic_dns_request_fail(request, "ENOMEM", "DNS response exceeds the closed result limit");
        return 0;
    }
    if (request->count == request->capacity) {
        size_t capacity = request->capacity == 0 ? 8 : request->capacity * 2;
        char **values = realloc(request->values, capacity * sizeof(*values));
        if (values == NULL) {
            tsonic_dns_request_fail(request, "ENOMEM", "Unable to allocate DNS results");
            return 0;
        }
        request->values = values;
        request->capacity = capacity;
    }
    char *copy = malloc(size);
    if (copy == NULL) {
        tsonic_dns_request_fail(request, "ENOMEM", "Unable to allocate DNS result text");
        return 0;
    }
    memcpy(copy, value, size);
    request->values[request->count++] = copy;
    request->bytes += size;
    return 1;
}

void tsonic_dns_request_fail(TsonicDnsRequest *request, const char *code, const char *message) {
    request->failed = 1;
    snprintf(request->code, sizeof(request->code), "%s", code);
    snprintf(request->error, sizeof(request->error), "%s", message);
}

void tsonic_dns_request_complete(TsonicDnsRequest *request) {
    atomic_store_explicit(&request->ready, 1, memory_order_release);
    tsonic_node_dns_request_free(request);
}

int tsonic_node_dns_request_ready(TsonicDnsRequest *request) {
    return request != NULL && atomic_load_explicit(&request->ready, memory_order_acquire);
}

int tsonic_node_dns_request_failed(TsonicDnsRequest *request) {
    return tsonic_node_dns_request_ready(request) && request->failed;
}

const char *tsonic_node_dns_request_error(TsonicDnsRequest *request) {
    return tsonic_node_dns_request_ready(request) ? request->error : NULL;
}

const char *tsonic_node_dns_request_code(TsonicDnsRequest *request) {
    return tsonic_node_dns_request_ready(request) ? request->code : NULL;
}

size_t tsonic_node_dns_request_count(TsonicDnsRequest *request) {
    return tsonic_node_dns_request_ready(request) && !request->failed ? request->count : 0;
}

const char *tsonic_node_dns_request_value(TsonicDnsRequest *request, size_t index) {
    return index < tsonic_node_dns_request_count(request) ? request->values[index] : NULL;
}

int tsonic_node_dns_request_family(TsonicDnsRequest *request) {
    return tsonic_node_dns_request_ready(request) && !request->failed ? request->family : 0;
}

void tsonic_node_dns_request_free(TsonicDnsRequest *request) {
    if (request == NULL || atomic_fetch_sub_explicit(&request->references, 1, memory_order_acq_rel) != 1) return;
    for (size_t index = 0; index < request->count; index++) free(request->values[index]);
    free(request->values);
    free(request->input);
    free(request);
    atomic_fetch_sub_explicit(&live_requests, 1, memory_order_relaxed);
}
