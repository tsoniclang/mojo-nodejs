#include <arpa/inet.h>
#include <stdint.h>
#include <stdlib.h>

void tsonic_node_free(void *value) {
    free(value);
}

int32_t tsonic_node_is_ip(const char *value) {
    unsigned char bytes[sizeof(struct in6_addr)];
    if (inet_pton(AF_INET, value, bytes) == 1) return 4;
    if (inet_pton(AF_INET6, value, bytes) == 1) return 6;
    return 0;
}
