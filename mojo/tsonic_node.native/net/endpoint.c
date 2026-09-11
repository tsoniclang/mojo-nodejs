#define _POSIX_C_SOURCE 200809L
#include "endpoint.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <uv.h>

struct TsonicNetEndpoint {
    int descriptor;
    int listener;
    int backlog;
    int status;
    int resolving;
    int closed;
    int released;
    struct addrinfo *addresses;
    struct addrinfo *next_address;
    uv_getaddrinfo_t resolver;
};

static uv_loop_t resolution_loop;
static int resolution_loop_ready;
static int pending_resolutions;
static uint64_t completed_resolutions;

extern int tsonic_node_socket_accept(int listener, int *status);
extern int tsonic_node_socket_nonblocking(int descriptor);

static void release_addresses(TsonicNetEndpoint *endpoint) {
    if (endpoint->addresses != NULL) uv_freeaddrinfo(endpoint->addresses);
    endpoint->addresses = NULL;
    endpoint->next_address = NULL;
}

static void close_descriptor(TsonicNetEndpoint *endpoint) {
    if (endpoint->descriptor >= 0) close(endpoint->descriptor);
    endpoint->descriptor = -1;
}

static void attempt_address(TsonicNetEndpoint *endpoint, int family, int protocol,
                            const struct sockaddr *address, socklen_t length) {
    int descriptor = socket(family, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, protocol);
    if (descriptor < 0) {
        endpoint->status = uv_translate_sys_error(errno);
        return;
    }
    if (endpoint->listener) {
        int enabled = 1;
        if (setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled)) == 0 &&
            bind(descriptor, address, length) == 0 && listen(descriptor, endpoint->backlog) == 0) {
            endpoint->descriptor = descriptor;
            endpoint->status = 1;
            return;
        }
    } else {
        int connected = connect(descriptor, address, length);
        if (connected == 0 || errno == EINPROGRESS || errno == EINTR) {
            endpoint->descriptor = descriptor;
            endpoint->status = connected == 0 ? 1 : 0;
            return;
        }
    }
    endpoint->status = uv_translate_sys_error(errno);
    close(descriptor);
}

static void next_address(TsonicNetEndpoint *endpoint) {
    if (endpoint->status >= 0) endpoint->status = UV_EADDRNOTAVAIL;
    while (endpoint->next_address != NULL) {
        const struct addrinfo *address = endpoint->next_address;
        endpoint->next_address = address->ai_next;
        if (address->ai_family != AF_INET && address->ai_family != AF_INET6) continue;
        attempt_address(endpoint, address->ai_family, address->ai_protocol, address->ai_addr, address->ai_addrlen);
        if (endpoint->status >= 0) {
            if (endpoint->status == 1) release_addresses(endpoint);
            return;
        }
    }
    release_addresses(endpoint);
}

static void resolved(uv_getaddrinfo_t *request, int status, struct addrinfo *addresses) {
    TsonicNetEndpoint *endpoint = request->data;
    endpoint->resolving = 0;
    --pending_resolutions;
    ++completed_resolutions;
    if (endpoint->closed) {
        if (addresses != NULL) uv_freeaddrinfo(addresses);
        if (endpoint->released) free(endpoint);
        return;
    }
    if (status < 0) {
        endpoint->status = status;
        if (addresses != NULL) uv_freeaddrinfo(addresses);
        return;
    }
    size_t count = 0;
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        if (++count > 4096u) {
            uv_freeaddrinfo(addresses);
            endpoint->status = UV_E2BIG;
            return;
        }
    }
    endpoint->addresses = addresses;
    endpoint->next_address = addresses;
    next_address(endpoint);
}

TsonicNetEndpoint *tsonic_node_net_endpoint_new(const char *host, int port, int listener, int backlog) {
    TsonicNetEndpoint *endpoint = calloc(1, sizeof(*endpoint));
    if (endpoint == NULL) return NULL;
    endpoint->descriptor = -1;
    endpoint->listener = listener != 0;
    endpoint->backlog = backlog == 0 ? 511 : backlog;
    if (host == NULL || port < 0 || port > 65535 || backlog < 0) {
        endpoint->status = UV_EINVAL;
        return endpoint;
    }
    const char *selected_host = listener && host[0] == '\0' ? "::" : host;
    struct sockaddr_in ipv4;
    struct sockaddr_in6 ipv6;
    if (uv_ip4_addr(selected_host, port, &ipv4) == 0) {
        attempt_address(endpoint, AF_INET, IPPROTO_TCP, (const struct sockaddr *)&ipv4, sizeof(ipv4));
        return endpoint;
    }
    if (uv_ip6_addr(selected_host, port, &ipv6) == 0) {
        attempt_address(endpoint, AF_INET6, IPPROTO_TCP, (const struct sockaddr *)&ipv6, sizeof(ipv6));
        if (endpoint->status < 0 && listener && host[0] == '\0') {
            uv_ip4_addr("0.0.0.0", port, &ipv4);
            attempt_address(endpoint, AF_INET, IPPROTO_TCP, (const struct sockaddr *)&ipv4, sizeof(ipv4));
        }
        return endpoint;
    }
    if (!resolution_loop_ready) {
        int status = uv_loop_init(&resolution_loop);
        if (status < 0) {
            endpoint->status = status;
            return endpoint;
        }
        resolution_loop_ready = 1;
    }
    if (pending_resolutions >= 1024) {
        endpoint->status = UV_ENOBUFS;
        return endpoint;
    }
    char service[6];
    snprintf(service, sizeof(service), "%u", (unsigned int)port);
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = listener ? AI_PASSIVE : 0;
    endpoint->resolver.data = endpoint;
    int status = uv_getaddrinfo(
        &resolution_loop, &endpoint->resolver, resolved,
        host[0] == '\0' && listener ? NULL : host, service, &hints
    );
    if (status < 0) {
        endpoint->status = status;
    } else {
        endpoint->resolving = 1;
        ++pending_resolutions;
    }
    return endpoint;
}

void tsonic_node_net_endpoint_close(TsonicNetEndpoint *endpoint) {
    if (endpoint == NULL || endpoint->closed) return;
    endpoint->closed = 1;
    endpoint->status = UV_ECANCELED;
    close_descriptor(endpoint);
    release_addresses(endpoint);
    if (endpoint->resolving) uv_cancel((uv_req_t *)&endpoint->resolver);
}

void tsonic_node_net_endpoint_free(TsonicNetEndpoint *endpoint) {
    if (endpoint == NULL) return;
    tsonic_node_net_endpoint_close(endpoint);
    endpoint->released = 1;
    if (!endpoint->resolving) free(endpoint);
}

int tsonic_node_net_endpoint_progress(TsonicNetEndpoint *endpoint) {
    if (endpoint == NULL) return UV_EINVAL;
    if (endpoint->status != 0 || endpoint->resolving) return endpoint->status;
    if (endpoint->descriptor < 0) return UV_EBADF;
    struct pollfd descriptor = {endpoint->descriptor, POLLOUT, 0};
    int status;
    do { status = poll(&descriptor, 1, 0); } while (status < 0 && errno == EINTR);
    if (status == 0) return 0;
    int error = 0;
    socklen_t length = sizeof(error);
    if (status < 0 || getsockopt(endpoint->descriptor, SOL_SOCKET, SO_ERROR, &error, &length) < 0) {
        error = errno;
    }
    if (error == 0) {
        endpoint->status = 1;
        release_addresses(endpoint);
    } else {
        close_descriptor(endpoint);
        endpoint->status = uv_translate_sys_error(error);
        next_address(endpoint);
    }
    return endpoint->status;
}

TsonicNetEndpoint *tsonic_node_net_endpoint_adopt(int descriptor, int *status) {
    if (descriptor < 0 || status == NULL) {
        if (descriptor >= 0) close(descriptor);
        if (status != NULL) *status = UV_EINVAL;
        return NULL;
    }
    *status = 0;
    if (tsonic_node_socket_nonblocking(descriptor) < 0) {
        *status = uv_translate_sys_error(errno);
        close(descriptor);
        return NULL;
    }
    TsonicNetEndpoint *endpoint = calloc(1, sizeof(*endpoint));
    if (endpoint == NULL) {
        close(descriptor);
        *status = UV_ENOMEM;
        return NULL;
    }
    endpoint->descriptor = descriptor;
    endpoint->status = 1;
    return endpoint;
}

TsonicNetEndpoint *tsonic_node_net_endpoint_accept(TsonicNetEndpoint *listener, int *status) {
    if (status == NULL) return NULL;
    if (listener == NULL || listener->status != 1 || !listener->listener || listener->closed) {
        *status = UV_EINVAL;
        return NULL;
    }
    int descriptor = tsonic_node_socket_accept(listener->descriptor, status);
    return descriptor < 0 ? NULL : tsonic_node_net_endpoint_adopt(descriptor, status);
}

int tsonic_node_net_endpoint_descriptor(const TsonicNetEndpoint *endpoint) {
    return endpoint == NULL || endpoint->closed ? -1 : endpoint->descriptor;
}

int tsonic_node_net_endpoint_no_delay(TsonicNetEndpoint *endpoint, int enabled) {
    int descriptor = tsonic_node_net_endpoint_descriptor(endpoint);
    if (descriptor < 0) return UV_EBADF;
    return setsockopt(descriptor, IPPROTO_TCP, TCP_NODELAY, &enabled, sizeof(enabled)) == 0
        ? 0 : uv_translate_sys_error(errno);
}

int tsonic_node_net_endpoint_shutdown(TsonicNetEndpoint *endpoint) {
    int descriptor = tsonic_node_net_endpoint_descriptor(endpoint);
    if (descriptor < 0) return UV_EBADF;
    int status;
    do { status = shutdown(descriptor, SHUT_WR); } while (status < 0 && errno == EINTR);
    return status == 0 ? 0 : uv_translate_sys_error(errno);
}

int tsonic_node_net_endpoint_address(
    const TsonicNetEndpoint *endpoint, int peer, char *address, size_t capacity,
    int *port, int *family
) {
    int descriptor = tsonic_node_net_endpoint_descriptor(endpoint);
    if (descriptor < 0 || address == NULL || port == NULL || family == NULL) return UV_EINVAL;
    struct sockaddr_storage storage;
    socklen_t length = sizeof(storage);
    int status = peer ? getpeername(descriptor, (struct sockaddr *)&storage, &length)
                      : getsockname(descriptor, (struct sockaddr *)&storage, &length);
    if (status < 0) return uv_translate_sys_error(errno);
    const void *bytes;
    if (storage.ss_family == AF_INET) {
        const struct sockaddr_in *value = (const struct sockaddr_in *)&storage;
        bytes = &value->sin_addr;
        *port = ntohs(value->sin_port);
        *family = 4;
    } else if (storage.ss_family == AF_INET6) {
        const struct sockaddr_in6 *value = (const struct sockaddr_in6 *)&storage;
        bytes = &value->sin6_addr;
        *port = ntohs(value->sin6_port);
        *family = 6;
    } else {
        return UV_EAFNOSUPPORT;
    }
    return inet_ntop(storage.ss_family, bytes, address, (socklen_t)capacity) != NULL
        ? 0 : uv_translate_sys_error(errno);
}

int tsonic_node_net_resolution_poll(void) {
    if (!resolution_loop_ready) return 0;
    uint64_t before = completed_resolutions;
    uv_run(&resolution_loop, UV_RUN_NOWAIT);
    return before != completed_resolutions;
}

int tsonic_node_net_resolution_pending(void) {
    return pending_resolutions != 0;
}
