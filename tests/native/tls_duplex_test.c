#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/tls/api.h"
#include "../../mojo/tsonic_node.native/net/endpoint.h"
#include "../../mojo/tsonic_node.native/tls/model.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <uv.h>

typedef struct {
    void *context;
    void *client;
    void *peer;
} Pair;

static void pause_turn(void) {
    struct timespec duration = {0, 1000000};
    nanosleep(&duration, NULL);
}

static char *fixture(const char *path) {
    FILE *file = fopen(path, "rb");
    assert(file != NULL);
    assert(fseek(file, 0, SEEK_END) == 0);
    long length = ftell(file);
    assert(length > 0 && length < 1048576);
    rewind(file);
    char *text = malloc((size_t)length + 1u);
    assert(text != NULL);
    assert(fread(text, 1u, (size_t)length, file) == (size_t)length);
    text[length] = '\0';
    assert(fclose(file) == 0);
    return text;
}

static void progress(Pair pair) {
    char *error = NULL;
    tsonic_node_net_resolution_poll();
    assert(tsonic_node_tls_progress(pair.client, &error) >= 0);
    assert(error == NULL);
    if (pair.peer != NULL) {
        assert(tsonic_node_tls_progress(pair.peer, &error) >= 0);
        assert(error == NULL);
    }
}

static Pair connect_pair(const char *certificate, const char *key) {
    char *error = NULL;
    Pair pair = {0};
    pair.context = tsonic_node_tls_server_create(key, certificate, "", NULL, 0u, 0, 1, &error);
    assert(pair.context != NULL && error == NULL);
    TsonicNetEndpoint *listener = tsonic_node_net_endpoint_new("127.0.0.1", 0, 1);
    assert(listener != NULL && tsonic_node_net_endpoint_progress(listener) == 1);
    char address[46];
    int port = 0;
    int family = 0;
    assert(tsonic_node_net_endpoint_address(listener, 0, address, sizeof(address), &port, &family) == 0);
    pair.client = tsonic_node_tls_connect("127.0.0.1", "localhost", "", port, 1, certificate, 1, NULL, 0u, &error);
    assert(pair.client != NULL && error == NULL);
    uint64_t deadline = uv_hrtime() + 5000000000u;
    while ((pair.peer == NULL || !tsonic_node_tls_ready(pair.client) || !tsonic_node_tls_ready(pair.peer)) && uv_hrtime() < deadline) {
        progress(pair);
        if (pair.peer == NULL) {
            int status = 0;
            TsonicNetEndpoint *accepted = tsonic_node_net_endpoint_accept(listener, &status);
            assert(status == 0);
            if (accepted != NULL) {
                int descriptor = dup(tsonic_node_net_endpoint_descriptor(accepted));
                assert(descriptor >= 0);
                tsonic_node_net_endpoint_free(accepted);
                pair.peer = tsonic_node_tls_server_accept(pair.context, descriptor, &error);
                assert(pair.peer != NULL && error == NULL);
            }
        }
        pause_turn();
    }
    tsonic_node_net_endpoint_free(listener);
    assert(tsonic_node_tls_ready(pair.client));
    assert(tsonic_node_tls_ready(pair.peer));
    assert(tsonic_node_tls_authorized(pair.client));
    assert(tsonic_node_tls_authorization_error(pair.client) == NULL);
    assert(tsonic_node_tls_servername(pair.client)[0] == '\0');
    assert(tsonic_node_tls_servername(pair.peer)[0] == '\0');
    assert(tsonic_node_tls_alpn(pair.client) == NULL);
    assert(tsonic_node_tls_set_no_delay(pair.client, 1) == 0);
    return pair;
}

static void free_pair(Pair pair) {
    tsonic_node_tls_socket_free(pair.client);
    tsonic_node_tls_socket_free(pair.peer);
    tsonic_node_tls_server_free(pair.context);
}

static void duplex_after_end(const char *certificate, const char *key) {
    Pair pair = connect_pair(certificate, key);
    char *error = NULL;
    assert(tsonic_node_tls_write(pair.client, (const uint8_t *)"request", 7u, &error) == 7);
    assert(error == NULL);
    assert(tsonic_node_tls_bytes_written(pair.client) == 7u);
    assert(tsonic_node_tls_end(pair.client, &error) == 1 && error == NULL);
    uint8_t input[65536];
    size_t received = 0u;
    int ended = 0;
    uint64_t deadline = uv_hrtime() + 5000000000u;
    while (!ended && uv_hrtime() < deadline) {
        progress(pair);
        int64_t count = tsonic_node_tls_read(pair.peer, input, sizeof(input), &error);
        assert(count >= 0 || count == -2);
        assert(error == NULL);
        if (count > 0) {
            assert(received + (size_t)count <= 7u);
            assert(memcmp(input, "request" + received, (size_t)count) == 0);
            received += (size_t)count;
        }
        ended = count == 0;
        if (!ended) pause_turn();
    }
    assert(ended && received == 7u);
    assert(tsonic_node_tls_write_ended(pair.client));
    assert(tsonic_node_tls_read_ended(pair.peer));
    assert(!tsonic_node_tls_closed(pair.client));
    assert(!tsonic_node_tls_closed(pair.peer));
    const size_t total = 3u * 1024u * 1024u;
    uint8_t *response = malloc(total);
    assert(response != NULL);
    for (size_t index = 0u; index < total; index += 1u) response[index] = (uint8_t)(index % 251u);
    assert(tsonic_node_tls_write(pair.peer, response, total, &error) == (int64_t)total);
    assert(tsonic_node_tls_bytes_written(pair.peer) == total);
    assert(tsonic_node_tls_end(pair.peer, &error) == 1 && error == NULL);
    received = 0u;
    ended = 0;
    deadline = uv_hrtime() + 10000000000u;
    while (!ended && uv_hrtime() < deadline) {
        progress(pair);
        int64_t count = tsonic_node_tls_read(pair.client, input, sizeof(input), &error);
        assert(count >= 0 || count == -2);
        assert(error == NULL);
        if (count > 0) {
            assert(received + (size_t)count <= total);
            assert(memcmp(input, response + received, (size_t)count) == 0);
            received += (size_t)count;
        }
        ended = count == 0;
        if (count == -2) pause_turn();
    }
    assert(ended && received == total);
    assert(tsonic_node_tls_closed(pair.client));
    assert(tsonic_node_tls_closed(pair.peer));
    assert(tsonic_node_tls_bytes_read(pair.client) == total);
    assert(tsonic_node_tls_queued_bytes(pair.peer) == 0u);
    free(response);
    free_pair(pair);
}

static void truncated_peer_is_not_authenticated_eof(const char *certificate, const char *key) {
    Pair pair = connect_pair(certificate, key);
    tsonic_node_tls_destroy(pair.peer);
    char *error = NULL;
    int status = -2;
    uint8_t bytes[1024];
    uint64_t deadline = uv_hrtime() + 5000000000u;
    while (status == -2 && uv_hrtime() < deadline) {
        status = (int)tsonic_node_tls_read(pair.client, bytes, sizeof(bytes), &error);
        if (status == -2) pause_turn();
    }
    assert(status == -1 && error != NULL);
    free(error);
    assert(tsonic_node_tls_closed(pair.client));
    free_pair(pair);
}

static size_t receive_payload(void *socket, const uint8_t *expected, size_t received, size_t total, int *ended) {
    uint8_t bytes[32768];
    char *error = NULL;
    int64_t count = tsonic_node_tls_read(socket, bytes, sizeof(bytes), &error);
    assert(count >= 0 || count == -2);
    assert(error == NULL);
    if (count > 0) {
        assert(received + (size_t)count <= total);
        assert(memcmp(bytes, expected + received, (size_t)count) == 0);
        received += (size_t)count;
    }
    if (count == 0) *ended = 1;
    return received;
}

static void simultaneous_backpressure(const char *certificate, const char *key) {
    Pair pair = connect_pair(certificate, key);
    int capacity = 4096;
    assert(setsockopt(((TsonicTlsSocket *)pair.client)->descriptor, SOL_SOCKET, SO_SNDBUF, &capacity, sizeof(capacity)) == 0);
    assert(setsockopt(((TsonicTlsSocket *)pair.peer)->descriptor, SOL_SOCKET, SO_SNDBUF, &capacity, sizeof(capacity)) == 0);
    const size_t prefix = 3u * 1024u * 1024u;
    const size_t total = prefix + 19u;
    uint8_t *left = malloc(total);
    uint8_t *right = malloc(total);
    assert(left != NULL && right != NULL);
    for (size_t index = 0; index < total; index++) {
        left[index] = (uint8_t)(index % 251u);
        right[index] = (uint8_t)(255u - index % 247u);
    }
    char *error = NULL;
    assert(tsonic_node_tls_write(pair.client, left, prefix, &error) == (int64_t)prefix && error == NULL);
    assert(tsonic_node_tls_write(pair.peer, right, prefix, &error) == (int64_t)prefix && error == NULL);
    for (int turn = 0; turn < 32; turn++) progress(pair);
    assert(tsonic_node_tls_queued_bytes(pair.client) > 0u);
    assert(tsonic_node_tls_queued_bytes(pair.peer) > 0u);
    assert(tsonic_node_tls_write(pair.client, left + prefix, total - prefix, &error) == (int64_t)(total - prefix) && error == NULL);
    assert(tsonic_node_tls_write(pair.peer, right + prefix, total - prefix, &error) == (int64_t)(total - prefix) && error == NULL);
    assert(tsonic_node_tls_end(pair.client, &error) == 1 && error == NULL);
    assert(tsonic_node_tls_end(pair.peer, &error) == 1 && error == NULL);
    size_t left_received = 0u;
    size_t right_received = 0u;
    int left_ended = 0;
    int right_ended = 0;
    uint64_t deadline = uv_hrtime() + 20000000000u;
    while ((!left_ended || !right_ended) && uv_hrtime() < deadline) {
        progress(pair);
        if (!left_ended) left_received = receive_payload(pair.client, right, left_received, total, &left_ended);
        if (!right_ended) right_received = receive_payload(pair.peer, left, right_received, total, &right_ended);
        assert(BIO_ctrl_pending(SSL_get_rbio(((TsonicTlsSocket *)pair.client)->ssl)) <= 65536u);
        assert(BIO_ctrl_pending(SSL_get_rbio(((TsonicTlsSocket *)pair.peer)->ssl)) <= 65536u);
        if (!left_ended || !right_ended) pause_turn();
    }
    assert(left_ended && right_ended && left_received == total && right_received == total);
    assert(tsonic_node_tls_queued_bytes(pair.client) == 0u);
    assert(tsonic_node_tls_queued_bytes(pair.peer) == 0u);
    assert(tsonic_node_tls_bytes_written(pair.client) == total);
    assert(tsonic_node_tls_bytes_written(pair.peer) == total);
    assert(tsonic_node_tls_closed(pair.client) && tsonic_node_tls_closed(pair.peer));
    free(left);
    free(right);
    free_pair(pair);
}

int main(void) {
    char *certificate = fixture("tests/fixtures/localhost-cert.pem");
    char *key = fixture("tests/fixtures/localhost-key.pem");
    duplex_after_end(certificate, key);
    simultaneous_backpressure(certificate, key);
    truncated_peer_is_not_authenticated_eof(certificate, key);
    free(certificate);
    free(key);
    return 0;
}
