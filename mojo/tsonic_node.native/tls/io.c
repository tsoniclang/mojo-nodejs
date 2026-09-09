#define _POSIX_C_SOURCE 200809L
#include "model.h"

int tsonic_node_tls_progress(void *value, char **error) {
    TsonicTlsSocket *socket = value;
    if (error == NULL) return -1;
    *error = NULL;
    if (socket == NULL || socket->failed) {
        tsonic_tls_set_error(error, "TLS connection has failed");
        return -1;
    }
    if (socket->descriptor < 0 && !socket->connecting) return 0;
    if (!socket->ready) {
        if (socket->connecting) {
            int status = tsonic_node_net_endpoint_progress(socket->endpoint);
            if (status == 0) return 0;
            if (status < 0) {
                tsonic_tls_set_error(error, uv_strerror(status));
                goto failed;
            }
            socket->descriptor = tsonic_node_net_endpoint_descriptor(socket->endpoint);
            if (tsonic_node_tls_attach_socket(socket->ssl, socket->descriptor) != 1) {
                tsonic_tls_set_ssl_error(error, "Unable to attach TLS connection transport");
                goto failed;
            }
            socket->connecting = 0;
        }
        ERR_clear_error();
        int result = SSL_do_handshake(socket->ssl);
        if (result != 1) {
            int reason = SSL_get_error(socket->ssl, result);
            if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return 0;
            tsonic_tls_set_ssl_error(error, "TLS handshake failed");
            goto failed;
        }
        if (!tsonic_tls_complete_handshake(socket, error)) goto failed;
    }
    size_t progressed = 0u;
    while (socket->output_offset < socket->output_length && progressed < 65536u) {
        if (socket->write_length == 0u) {
            size_t remaining = socket->output_length - socket->output_offset;
            socket->write_length = remaining > 16384u ? 16384u : remaining;
        }
        ERR_clear_error();
        int written = SSL_write(socket->ssl, socket->output + socket->output_offset, (int)socket->write_length);
        if (written <= 0) {
            int reason = SSL_get_error(socket->ssl, written);
            if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return 1;
            tsonic_tls_set_ssl_error(error, "TLS write failed");
            goto failed;
        }
        socket->output_offset += (size_t)written;
        progressed += (size_t)written;
        socket->write_length = 0u;
    }
    if (socket->output_offset == socket->output_length) {
        free(socket->output);
        socket->output = NULL;
        socket->output_offset = socket->output_length = 0u;
        if (socket->ending && !socket->write_ended) {
            ERR_clear_error();
            int result = SSL_shutdown(socket->ssl);
            if (result < 0) {
                int reason = SSL_get_error(socket->ssl, result);
                if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return 1;
                tsonic_tls_set_ssl_error(error, "TLS shutdown failed");
                goto failed;
            }
            socket->write_ended = 1;
            if (result == 1) socket->read_ended = 1;
        }
    }
    if (socket->write_ended && (socket->read_ended || socket->close_after_flush)) {
        tsonic_node_net_endpoint_close(socket->endpoint);
        socket->descriptor = -1;
    }
    return 1;
failed:
    socket->failed = 1;
    tsonic_node_net_endpoint_close(socket->endpoint);
    socket->connecting = 0;
    socket->descriptor = -1;
    return -1;
}

int tsonic_node_tls_ready(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && socket->ready && !socket->failed;
}

int tsonic_node_tls_closed(void *value) {
    TsonicTlsSocket *socket = value;
    return socket == NULL || (socket->descriptor < 0 && !socket->connecting);
}

int tsonic_node_tls_pending(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && !socket->failed && (socket->descriptor >= 0 || socket->connecting) &&
        (!socket->ready || socket->output_length != 0u || (socket->ending && !socket->write_ended));
}

int64_t tsonic_node_tls_write(
    void *value,
    const uint8_t *bytes,
    size_t length,
    char **error
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || socket->ssl == NULL || socket->ending || socket->failed ||
        (socket->descriptor < 0 && !socket->connecting) ||
        (length != 0u && bytes == NULL) || error == NULL) return -1;
    *error = NULL;
    size_t retained = socket->output_length - socket->output_offset;
    if (length > 268435456u - retained) {
        tsonic_tls_set_error(error, "TLS queued writes exceed the byte budget");
        return -1;
    }
    if (length == 0u) return 0;
    if (socket->output_offset != 0u) {
        memmove(socket->output, socket->output + socket->output_offset, retained);
        socket->output_length = retained;
        socket->output_offset = 0u;
    }
    unsigned char *output = realloc(socket->output, socket->output_length + length);
    if (output == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate queued TLS write");
        return -1;
    }
    memcpy(output + socket->output_length, bytes, length);
    socket->output = output;
    socket->output_length += length;
    socket->bytes_written += length;
    return (int64_t)length;
}

int64_t tsonic_node_tls_read(
    void *value,
    uint8_t *bytes,
    size_t capacity,
    char **error
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || socket->ssl == NULL || capacity > INT_MAX ||
        (capacity != 0u && bytes == NULL) || error == NULL) return -1;
    *error = NULL;
    if (capacity == 0u) return 0;
    if (tsonic_node_tls_progress(socket, error) < 0) return -1;
    if (socket->connecting) return -2;
    if (socket->descriptor < 0 || socket->read_ended) return 0;
    if (!socket->ready || socket->write_length != 0u) return -2;
    ERR_clear_error();
    int read = SSL_read(socket->ssl, bytes, (int)capacity);
    if (read > 0) {
        socket->bytes_read += (uint64_t)read;
        return read;
    }
    int ssl_error = SSL_get_error(socket->ssl, read);
    if (ssl_error == SSL_ERROR_ZERO_RETURN) {
        socket->read_ended = 1;
        if (socket->write_ended) {
            tsonic_node_net_endpoint_close(socket->endpoint);
            socket->descriptor = -1;
        }
        return 0;
    }
    if (ssl_error == SSL_ERROR_WANT_READ || ssl_error == SSL_ERROR_WANT_WRITE) return -2;
    tsonic_tls_set_ssl_error(error, "TLS read failed");
    socket->failed = 1;
    tsonic_node_net_endpoint_close(socket->endpoint);
    socket->descriptor = -1;
    return -1;
}

int32_t tsonic_node_tls_end(void *value, char **error) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || error == NULL) return 0;
    *error = NULL;
    socket->ending = 1;
    return tsonic_node_tls_progress(socket, error) >= 0;
}

int32_t tsonic_node_tls_finish_response(void *value, char **error) {
    TsonicTlsSocket *socket = value;
    if (socket == NULL || error == NULL) return 0;
    socket->close_after_flush = 1;
    return tsonic_node_tls_end(value, error);
}

int tsonic_node_tls_peek(void *value, char **error) {
    TsonicTlsSocket *socket = value;
    if (error == NULL || socket == NULL) return -1;
    *error = NULL;
    if (tsonic_node_tls_progress(value, error) < 0) return -1;
    if (socket->read_ended || (socket->descriptor < 0 && !socket->connecting)) return 0;
    if (!socket->ready || socket->write_length != 0u) return -2;
    unsigned char byte;
    ERR_clear_error();
    int result = SSL_peek(socket->ssl, &byte, 1);
    if (result > 0) return 1;
    int reason = SSL_get_error(socket->ssl, result);
    if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return -2;
    if (reason == SSL_ERROR_ZERO_RETURN) {
        socket->read_ended = 1;
        return 0;
    }
    tsonic_tls_set_ssl_error(error, "TLS read failed");
    socket->failed = 1;
    tsonic_node_net_endpoint_close(socket->endpoint);
    socket->descriptor = -1;
    return -1;
}

void tsonic_node_tls_destroy(void *value) {
    TsonicTlsSocket *socket = value;
    if (socket == NULL) return;
    tsonic_node_net_endpoint_close(socket->endpoint);
    socket->connecting = 0;
    socket->descriptor = -1;
    socket->ending = 1;
    free(socket->output);
    socket->output = NULL;
    socket->output_length = socket->output_offset = socket->write_length = 0u;
}
