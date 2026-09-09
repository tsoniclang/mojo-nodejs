#define _POSIX_C_SOURCE 200809L
#include "model.h"

void tsonic_node_tls_socket_free(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL) return;
    if (socket->ssl != NULL) SSL_free(socket->ssl);
    tsonic_node_net_endpoint_free(socket->endpoint);
    if (socket->context != NULL) SSL_CTX_free(socket->context);
    free(socket->authorization_error);
    free(socket->servername);
    free(socket->alpn);
    free(socket->output);
    free(socket);
}

int32_t tsonic_node_tls_authorized(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? 0 : socket->authorized;
}

const char *tsonic_node_tls_authorization_error(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? NULL : socket->authorization_error;
}

const char *tsonic_node_tls_servername(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? NULL : socket->servername;
}

const char *tsonic_node_tls_alpn(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? NULL : socket->alpn;
}

uint64_t tsonic_node_tls_bytes_read(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? 0u : socket->bytes_read;
}

uint64_t tsonic_node_tls_bytes_written(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    return socket == NULL ? 0u : socket->bytes_written;
}

int tsonic_node_tls_read_ended(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && socket->read_ended;
}

int tsonic_node_tls_write_ended(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && socket->write_ended;
}

uint64_t tsonic_node_tls_queued_bytes(void *value) {
    TsonicTlsSocket *socket = value;
    return socket == NULL ? 0u : socket->output_length - socket->output_offset;
}

uint64_t tsonic_node_tls_activity_bytes(void *value) {
    TsonicTlsSocket *socket = value;
    if (socket == NULL || socket->ssl == NULL) return 0u;
    BIO *reader = SSL_get_rbio(socket->ssl);
    BIO *writer = SSL_get_wbio(socket->ssl);
    return (reader == NULL ? 0u : BIO_number_read(reader)) +
        (writer == NULL ? 0u : BIO_number_written(writer));
}

int tsonic_node_tls_set_no_delay(void *value, int enabled) {
    TsonicTlsSocket *socket = value;
    return socket == NULL ? UV_EBADF : tsonic_node_net_endpoint_no_delay(socket->endpoint, enabled);
}
