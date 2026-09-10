#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/net/endpoint.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include <uv.h>

int64_t tsonic_node_socket_read(int descriptor, void *bytes, size_t capacity);
int64_t tsonic_node_socket_write(int descriptor, const void *bytes, size_t length);

static void pause_turn(void) {
    struct timespec duration = {0, 1000000};
    nanosleep(&duration, NULL);
}

static int endpoint_port(TsonicNetEndpoint *endpoint) {
    char address[46];
    int port = 0;
    int family = 0;
    assert(tsonic_node_net_endpoint_address(endpoint, 0, address, sizeof(address), &port, &family) == 0);
    assert(strcmp(address, "127.0.0.1") == 0 && family == 4 && port > 0);
    return port;
}

static int wait_ready(TsonicNetEndpoint *endpoint) {
    uint64_t deadline = uv_hrtime() + UINT64_C(5000000000);
    int status;
    do {
        tsonic_node_net_resolution_poll();
        status = tsonic_node_net_endpoint_progress(endpoint);
        if (status != 0) return status;
        pause_turn();
    } while (uv_hrtime() < deadline);
    assert(0 && "endpoint progress deadline exceeded");
    return 0;
}

static void duplex_and_half_close(void) {
    TsonicNetEndpoint *server = tsonic_node_net_endpoint_new("127.0.0.1", 0, 1);
    assert(server != NULL && wait_ready(server) == 1);
    TsonicNetEndpoint *client = tsonic_node_net_endpoint_new("localhost", endpoint_port(server), 0);
    assert(client != NULL && wait_ready(client) == 1);
    int status = 0;
    TsonicNetEndpoint *accepted = NULL;
    uint64_t deadline = uv_hrtime() + UINT64_C(5000000000);
    while (accepted == NULL && uv_hrtime() < deadline) {
        accepted = tsonic_node_net_endpoint_accept(server, &status);
        assert(status == 0);
        if (accepted == NULL) pause_turn();
    }
    assert(accepted != NULL);
    int client_fd = tsonic_node_net_endpoint_descriptor(client);
    int accepted_fd = tsonic_node_net_endpoint_descriptor(accepted);
    assert((fcntl(client_fd, F_GETFL) & O_NONBLOCK) != 0);
    assert((fcntl(accepted_fd, F_GETFD) & FD_CLOEXEC) != 0);
    assert(tsonic_node_net_endpoint_no_delay(client, 1) == 0);
    assert(tsonic_node_net_endpoint_no_delay(client, 0) == 0);
    unsigned char output[16384];
    unsigned char input[16384];
    memset(output, 179, sizeof(output));
    assert(tsonic_node_socket_read(accepted_fd, input, sizeof(input)) == -2);
    int capacity = 4096;
    assert(setsockopt(client_fd, SOL_SOCKET, SO_SNDBUF, &capacity, sizeof(capacity)) == 0);
    size_t sent = 0;
    size_t received = 0;
    const size_t total = 3u * 1024u * 1024u;
    int blocked = 0;
    while (sent < total) {
        int64_t count = tsonic_node_socket_write(client_fd, output, sizeof(output));
        if (count == -2) { blocked = 1; break; }
        assert(count > 0);
        sent += (size_t)count;
    }
    assert(blocked);
    deadline = uv_hrtime() + UINT64_C(10000000000);
    while (received < total && uv_hrtime() < deadline) {
        if (sent < total) {
            size_t count = total - sent < sizeof(output) ? total - sent : sizeof(output);
            int64_t written = tsonic_node_socket_write(client_fd, output, count);
            assert(written == -2 || written > 0);
            if (written > 0) sent += (size_t)written;
        }
        int64_t count = tsonic_node_socket_read(accepted_fd, input, sizeof(input));
        assert(count == -2 || count > 0);
        if (count > 0) {
            for (int64_t index = 0; index < count; ++index) assert(input[index] == 179);
            received += (size_t)count;
        } else pause_turn();
    }
    assert(sent == total && received == total);
    assert(tsonic_node_net_endpoint_shutdown(client) == 0);
    deadline = uv_hrtime() + UINT64_C(5000000000);
    int64_t ended = -2;
    while (ended == -2 && uv_hrtime() < deadline) {
        ended = tsonic_node_socket_read(accepted_fd, input, sizeof(input));
        if (ended == -2) pause_turn();
    }
    assert(ended == 0);
    assert(tsonic_node_socket_write(accepted_fd, "reply", 5) == 5);
    deadline = uv_hrtime() + UINT64_C(5000000000);
    int64_t count = -2;
    while (count == -2 && uv_hrtime() < deadline) {
        count = tsonic_node_socket_read(client_fd, input, sizeof(input));
        if (count == -2) pause_turn();
    }
    assert(count == 5 && memcmp(input, "reply", 5) == 0);
    tsonic_node_net_endpoint_close(client);
    tsonic_node_net_endpoint_close(client);
    assert(fcntl(client_fd, F_GETFD) < 0 && errno == EBADF);
    int replacement = open("/dev/null", O_RDONLY);
    assert(replacement >= 0);
    tsonic_node_net_endpoint_free(client);
    assert(fcntl(replacement, F_GETFD) >= 0);
    close(replacement);
    tsonic_node_net_endpoint_free(accepted);
    tsonic_node_net_endpoint_free(server);
}

static void failure_and_cancellation(void) {
    TsonicNetEndpoint *invalid = tsonic_node_net_endpoint_new("127.0.0.1", -1, 0);
    assert(invalid != NULL && wait_ready(invalid) == UV_EINVAL);
    tsonic_node_net_endpoint_free(invalid);
    TsonicNetEndpoint *server = tsonic_node_net_endpoint_new("127.0.0.1", 0, 1);
    assert(server != NULL && wait_ready(server) == 1);
    int port = endpoint_port(server);
    tsonic_node_net_endpoint_free(server);
    TsonicNetEndpoint *refused = tsonic_node_net_endpoint_new("127.0.0.1", port, 0);
    assert(refused != NULL && wait_ready(refused) == UV_ECONNREFUSED);
    tsonic_node_net_endpoint_free(refused);
    TsonicNetEndpoint *missing = tsonic_node_net_endpoint_new("invalid/host", 80, 0);
    assert(missing != NULL && wait_ready(missing) < 0);
    tsonic_node_net_endpoint_free(missing);
    for (int index = 0; index < 64; ++index) {
        TsonicNetEndpoint *pending = tsonic_node_net_endpoint_new("localhost", 80, 0);
        assert(pending != NULL);
        tsonic_node_net_endpoint_free(pending);
    }
    uint64_t deadline = uv_hrtime() + UINT64_C(5000000000);
    while (tsonic_node_net_resolution_pending() && uv_hrtime() < deadline) {
        tsonic_node_net_resolution_poll();
        pause_turn();
    }
    assert(!tsonic_node_net_resolution_pending());
}

int main(void) {
    duplex_and_half_close();
    failure_and_cancellation();
    return 0;
}
