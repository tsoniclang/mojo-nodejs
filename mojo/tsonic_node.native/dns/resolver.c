#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uv_once_t library_once = UV_ONCE_INIT;
static int library_status;
static uv_once_t default_once = UV_ONCE_INIT;
static TsonicDnsResolver *default_resolver;
static int default_status;

static void initialize_library(void) {
    library_status = ares_library_init(ARES_LIB_INIT_ALL);
}

TsonicDnsResolver *tsonic_node_dns_resolver_new(const char *servers, int *status) {
    if (status == NULL) return NULL;
    uv_once(&library_once, initialize_library);
    *status = library_status;
    if (*status != ARES_SUCCESS) return NULL;
    TsonicDnsResolver *resolver = calloc(1, sizeof(*resolver));
    if (resolver == NULL) { *status = ARES_ENOMEM; return NULL; }
    struct ares_options options;
    memset(&options, 0, sizeof(options));
    options.evsys = ARES_EVSYS_DEFAULT;
    options.qcache_max_ttl = 0;
    options.tries = 4;
    *status = ares_init_options(&resolver->channel, &options, ARES_OPT_EVENT_THREAD | ARES_OPT_QUERY_CACHE | ARES_OPT_TRIES);
    if (*status == ARES_SUCCESS && servers != NULL) *status = ares_set_servers_ports_csv(resolver->channel, servers);
    if (*status != ARES_SUCCESS) {
        if (resolver->channel != NULL) ares_destroy(resolver->channel);
        free(resolver);
        return NULL;
    }
    return resolver;
}

void tsonic_node_dns_resolver_free(TsonicDnsResolver *resolver) {
    if (resolver == NULL) return;
    ares_destroy(resolver->channel);
    free(resolver);
}

static void initialize_default(void) {
    default_resolver = tsonic_node_dns_resolver_new(NULL, &default_status);
}

TsonicDnsRequest *tsonic_node_dns_default_query_start(const char *input, int kind) {
    uv_once(&default_once, initialize_default);
    if (default_resolver != NULL) return tsonic_node_dns_query_start(default_resolver, input, kind);
    TsonicDnsRequest *request = tsonic_dns_request_new(input, kind);
    if (request != NULL) {
        tsonic_dns_dns_failure(request, (ares_status_t)default_status);
        tsonic_dns_request_complete(request);
    }
    return request;
}

static int reverse_name(const char *input, char *output, size_t capacity) {
    uint8_t bytes[16];
    if (inet_pton(AF_INET, input, bytes) == 1) {
        int length = snprintf(output, capacity, "%u.%u.%u.%u.in-addr.arpa", bytes[3], bytes[2], bytes[1], bytes[0]);
        return length > 0 && (size_t)length < capacity;
    }
    if (inet_pton(AF_INET6, input, bytes) != 1 || capacity < 74) return 0;
    static const char hex[] = "0123456789abcdef";
    size_t offset = 0;
    for (size_t index = 16; index > 0; index--) {
        output[offset++] = hex[bytes[index - 1] & 15];
        output[offset++] = '.';
        output[offset++] = hex[bytes[index - 1] >> 4];
        output[offset++] = '.';
    }
    memcpy(output + offset, "ip6.arpa", 9);
    return 1;
}

static void query_complete(void *argument, ares_status_t status, size_t timeouts, const ares_dns_record_t *records) {
    (void)timeouts;
    TsonicDnsRequest *request = argument;
    if (status != ARES_SUCCESS) tsonic_dns_dns_failure(request, status);
    else tsonic_dns_collect_records(request, records);
    tsonic_dns_request_complete(request);
}

TsonicDnsRequest *tsonic_node_dns_query_start(TsonicDnsResolver *resolver, const char *input, int kind) {
    TsonicDnsRequest *request = tsonic_dns_request_new(input, kind);
    if (request == NULL) return NULL;
    ares_dns_rec_type_t type = kind == 4 ? ARES_REC_TYPE_A : kind == 6 ? ARES_REC_TYPE_AAAA : ARES_REC_TYPE_PTR;
    char reverse[128];
    const char *name = request->input;
    if (resolver == NULL || (kind != 4 && kind != 6 && kind != -1)) {
        tsonic_dns_request_fail(request, "EINVAL", "Invalid DNS resolver or query kind");
    } else if (kind == -1) {
        if (!reverse_name(input, reverse, sizeof(reverse))) tsonic_dns_request_fail(request, "EINVAL", "Reverse DNS requires a valid IP address");
        else name = reverse;
    }
    if (request->failed) tsonic_dns_request_complete(request);
    else ares_query_dnsrec(resolver->channel, name, ARES_CLASS_IN, type, query_complete, request, NULL);
    return request;
}
