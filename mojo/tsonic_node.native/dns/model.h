#ifndef TSONIC_NODE_DNS_MODEL_H
#define TSONIC_NODE_DNS_MODEL_H

#include "api.h"
#include <ares.h>
#include <stdatomic.h>
#include <uv.h>

#define TSONIC_DNS_RESULT_LIMIT 4096u
#define TSONIC_DNS_BYTE_LIMIT (1024u * 1024u)
#define TSONIC_DNS_REQUEST_LIMIT 16384u

struct TsonicDnsRequest {
    atomic_uint references;
    atomic_int ready;
    int failed;
    int kind;
    int family;
    size_t count;
    size_t capacity;
    size_t bytes;
    char **values;
    char *input;
    char error[256];
    char code[32];
    uv_getaddrinfo_t lookup;
};

struct TsonicDnsResolver {
    ares_channel_t *channel;
};

TsonicDnsRequest *tsonic_dns_request_new(const char *input, int kind);
int tsonic_dns_result_append(TsonicDnsRequest *request, const char *value);
void tsonic_dns_request_fail(TsonicDnsRequest *request, const char *code, const char *message);
void tsonic_dns_request_complete(TsonicDnsRequest *request);
void tsonic_dns_dns_failure(TsonicDnsRequest *request, ares_status_t status);
void tsonic_dns_collect_records(TsonicDnsRequest *request, const ares_dns_record_t *records);

#endif
