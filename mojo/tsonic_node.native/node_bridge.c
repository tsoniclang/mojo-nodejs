#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define TSONIC_NODE_MAX_HOST 1025

static char *copy_text(const char *value) {
    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, value, length + 1);
    return copy;
}

static void set_error(char **error, const char *message) {
    if (error != NULL) {
        *error = copy_text(message);
    }
}

void tsonic_node_free(void *value) {
    free(value);
}

char *tsonic_node_dns_lookup(
    const char *hostname,
    int32_t *family,
    char **error
) {
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    int status = getaddrinfo(hostname, NULL, &hints, &addresses);
    if (status != 0) {
        set_error(error, gai_strerror(status));
        return NULL;
    }
    char text[INET6_ADDRSTRLEN];
    char *result = NULL;
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        const void *bytes = NULL;
        if (address->ai_family == AF_INET) {
            bytes = &((const struct sockaddr_in *)address->ai_addr)->sin_addr;
            *family = 4;
        } else if (address->ai_family == AF_INET6) {
            bytes = &((const struct sockaddr_in6 *)address->ai_addr)->sin6_addr;
            *family = 6;
        }
        if (bytes != NULL && inet_ntop(address->ai_family, bytes, text, sizeof(text)) != NULL) {
            result = copy_text(text);
            break;
        }
    }
    freeaddrinfo(addresses);
    if (result == NULL) {
        set_error(error, "DNS lookup returned no IP address");
    }
    return result;
}

char *tsonic_node_dns_resolve(
    const char *hostname,
    int32_t requested_family,
    char **error
) {
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = requested_family == 4 ? AF_INET : AF_INET6;
    hints.ai_socktype = SOCK_STREAM;
    int status = getaddrinfo(hostname, NULL, &hints, &addresses);
    if (status != 0) {
        set_error(error, gai_strerror(status));
        return NULL;
    }
    size_t capacity = 256;
    size_t length = 0;
    char *result = (char *)malloc(capacity);
    if (result == NULL) {
        freeaddrinfo(addresses);
        set_error(error, "Unable to allocate DNS result");
        return NULL;
    }
    result[0] = '\0';
    char text[INET6_ADDRSTRLEN];
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        const void *bytes = requested_family == 4
            ? (const void *)&((const struct sockaddr_in *)address->ai_addr)->sin_addr
            : (const void *)&((const struct sockaddr_in6 *)address->ai_addr)->sin6_addr;
        if (inet_ntop(address->ai_family, bytes, text, sizeof(text)) == NULL) {
            continue;
        }
        size_t item_length = strlen(text);
        size_t required = length + item_length + (length == 0 ? 1 : 2);
        if (required > capacity) {
            while (capacity < required) {
                capacity *= 2;
            }
            char *expanded = (char *)realloc(result, capacity);
            if (expanded == NULL) {
                free(result);
                freeaddrinfo(addresses);
                set_error(error, "Unable to grow DNS result");
                return NULL;
            }
            result = expanded;
        }
        if (length != 0) {
            result[length++] = '\n';
        }
        memcpy(result + length, text, item_length);
        length += item_length;
        result[length] = '\0';
    }
    freeaddrinfo(addresses);
    if (length == 0) {
        free(result);
        set_error(error, "DNS resolution returned no IP addresses");
        return NULL;
    }
    return result;
}

char *tsonic_node_dns_reverse(const char *address, char **error) {
    struct sockaddr_storage storage;
    socklen_t length;
    memset(&storage, 0, sizeof(storage));
    struct sockaddr_in *ipv4 = (struct sockaddr_in *)&storage;
    struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)&storage;
    if (inet_pton(AF_INET, address, &ipv4->sin_addr) == 1) {
        ipv4->sin_family = AF_INET;
        length = sizeof(*ipv4);
    } else if (inet_pton(AF_INET6, address, &ipv6->sin6_addr) == 1) {
        ipv6->sin6_family = AF_INET6;
        length = sizeof(*ipv6);
    } else {
        set_error(error, "Invalid IP address");
        return NULL;
    }
    char hostname[TSONIC_NODE_MAX_HOST];
    int status = getnameinfo(
        (const struct sockaddr *)&storage,
        length,
        hostname,
        sizeof(hostname),
        NULL,
        0,
        NI_NAMEREQD
    );
    if (status != 0) {
        set_error(error, gai_strerror(status));
        return NULL;
    }
    return copy_text(hostname);
}

int32_t tsonic_node_is_ip(const char *value) {
    unsigned char bytes[sizeof(struct in6_addr)];
    if (inet_pton(AF_INET, value, bytes) == 1) {
        return 4;
    }
    if (inet_pton(AF_INET6, value, bytes) == 1) {
        return 6;
    }
    return 0;
}

static int32_t socket_for_address(
    const char *host,
    int32_t port,
    int passive,
    char **error
) {
    if (port < 0 || port > 65535) {
        set_error(error, "Port must be between 0 and 65535");
        return -1;
    }
    char service[16];
    snprintf(service, sizeof(service), "%d", port);
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = passive ? AI_PASSIVE : 0;
    int status = getaddrinfo(
        host == NULL || host[0] == '\0' ? NULL : host,
        service,
        &hints,
        &addresses
    );
    if (status != 0) {
        set_error(error, gai_strerror(status));
        return -1;
    }
    int descriptor = -1;
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        descriptor = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (descriptor < 0) {
            continue;
        }
        if (passive) {
            int enabled = 1;
            (void)setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
            if (bind(descriptor, address->ai_addr, address->ai_addrlen) == 0 &&
                listen(descriptor, 128) == 0) {
                break;
            }
        } else if (connect(descriptor, address->ai_addr, address->ai_addrlen) == 0) {
            break;
        }
        close(descriptor);
        descriptor = -1;
    }
    freeaddrinfo(addresses);
    if (descriptor < 0) {
        set_error(error, passive ? "Unable to bind network server" : "Unable to connect network socket");
    }
    return descriptor;
}

int32_t tsonic_node_net_connect(
    const char *host,
    int32_t port,
    char **error
) {
    return socket_for_address(host, port, 0, error);
}

int32_t tsonic_node_net_listen(
    const char *host,
    int32_t port,
    char **error
) {
    return socket_for_address(host, port, 1, error);
}

int32_t tsonic_node_net_set_no_delay(int32_t descriptor, int32_t enabled) {
    return setsockopt(
        descriptor,
        IPPROTO_TCP,
        TCP_NODELAY,
        &enabled,
        sizeof(enabled)
    );
}

int32_t tsonic_node_net_set_timeout(
    int32_t descriptor,
    int32_t milliseconds
) {
    if (milliseconds < 0) {
        return -1;
    }
    struct timeval timeout;
    timeout.tv_sec = milliseconds / 1000;
    timeout.tv_usec = (milliseconds % 1000) * 1000;
    if (setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0) {
        return -1;
    }
    return setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
}
