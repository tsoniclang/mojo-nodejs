#ifndef TSONIC_NODE_DNS_API_H
#define TSONIC_NODE_DNS_API_H

#include <stddef.h>

typedef struct TsonicDnsRequest TsonicDnsRequest;
typedef struct TsonicDnsResolver TsonicDnsResolver;

TsonicDnsResolver *tsonic_node_dns_resolver_new(const char *servers, int *status);
void tsonic_node_dns_resolver_free(TsonicDnsResolver *resolver);
TsonicDnsRequest *tsonic_node_dns_query_start(TsonicDnsResolver *resolver, const char *input, int kind);
TsonicDnsRequest *tsonic_node_dns_default_query_start(const char *input, int kind);
TsonicDnsRequest *tsonic_node_dns_lookup_start(const char *input, int family, int hints, int all, int order);
int tsonic_node_dns_lookup_hint(int field);
int tsonic_node_dns_lookup_poll(void);
int tsonic_node_dns_request_ready(TsonicDnsRequest *request);
int tsonic_node_dns_request_failed(TsonicDnsRequest *request);
const char *tsonic_node_dns_request_error(TsonicDnsRequest *request);
const char *tsonic_node_dns_request_code(TsonicDnsRequest *request);
size_t tsonic_node_dns_request_count(TsonicDnsRequest *request);
const char *tsonic_node_dns_request_value(TsonicDnsRequest *request, size_t index);
int tsonic_node_dns_request_family(TsonicDnsRequest *request, size_t index);
void tsonic_node_dns_request_free(TsonicDnsRequest *request);

#endif
