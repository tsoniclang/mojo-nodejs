#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <arpa/inet.h>
#include <netdb.h>
#include <string.h>

static uv_once_t lookup_once = UV_ONCE_INIT;
static uv_loop_t lookup_loop;
static uv_mutex_t lookup_mutex;
static int lookup_status;
static size_t completed_lookups;

static void initialize_loop(void) {
    lookup_status = uv_mutex_init(&lookup_mutex);
    if (lookup_status == 0) lookup_status = uv_loop_init(&lookup_loop);
}

static void lookup_complete(uv_getaddrinfo_t *handle, int status, struct addrinfo *addresses) {
    TsonicDnsRequest *request = handle->data;
    if (status != 0) {
        const char *code = status == UV_EAI_NONAME || status == UV_EAI_NODATA ? "ENOTFOUND" : uv_err_name(status);
        tsonic_dns_request_fail(request, code, uv_strerror(status));
    } else {
        for (const struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
            char text[INET6_ADDRSTRLEN];
            const void *bytes = NULL;
            if (address->ai_family == AF_INET) {
                bytes = &((const struct sockaddr_in *)address->ai_addr)->sin_addr;
                request->family = 4;
            } else if (address->ai_family == AF_INET6) {
                bytes = &((const struct sockaddr_in6 *)address->ai_addr)->sin6_addr;
                request->family = 6;
            }
            if (bytes != NULL && inet_ntop(address->ai_family, bytes, text, sizeof(text)) != NULL) {
                tsonic_dns_result_append(request, text);
                break;
            }
        }
        if (request->count == 0 && !request->failed) tsonic_dns_request_fail(request, "ENOTFOUND", "OS lookup returned no IP address");
    }
    if (addresses != NULL) uv_freeaddrinfo(addresses);
    completed_lookups++;
    tsonic_dns_request_complete(request);
}

TsonicDnsRequest *tsonic_node_dns_lookup_start(const char *input) {
    TsonicDnsRequest *request = tsonic_dns_request_new(input, 0);
    if (request == NULL) return NULL;
    uv_once(&lookup_once, initialize_loop);
    int status = lookup_status;
    if (status == 0) {
        struct addrinfo hints;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        request->lookup.data = request;
        uv_mutex_lock(&lookup_mutex);
        status = uv_getaddrinfo(&lookup_loop, &request->lookup, lookup_complete, request->input, NULL, &hints);
        uv_mutex_unlock(&lookup_mutex);
    }
    if (status != 0) {
        tsonic_dns_request_fail(request, uv_err_name(status), uv_strerror(status));
        tsonic_dns_request_complete(request);
    }
    return request;
}

int tsonic_node_dns_lookup_poll(void) {
    uv_once(&lookup_once, initialize_loop);
    if (lookup_status != 0) return 0;
    uv_mutex_lock(&lookup_mutex);
    size_t previous = completed_lookups;
    uv_run(&lookup_loop, UV_RUN_NOWAIT);
    int worked = previous != completed_lookups;
    uv_mutex_unlock(&lookup_mutex);
    return worked;
}
