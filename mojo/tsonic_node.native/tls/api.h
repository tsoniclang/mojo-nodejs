#ifndef TSONIC_NODE_TLS_API_H
#define TSONIC_NODE_TLS_API_H

#include <stddef.h>
#include <stdint.h>

void *tsonic_node_tls_context_create(const char *key_pem, const char *certificate_pem,
    const char *ca_pem, int32_t ca_present, const unsigned char *pfx, size_t pfx_length,
    int32_t pfx_present, const char *passphrase, int32_t minimum, int32_t maximum, char **error);
int tsonic_node_tls_context_retain(void *context);
void tsonic_node_tls_context_free(void *context);
int tsonic_node_tls_context_apply(void *source, void *destination, char **error);
void *tsonic_node_tls_connect(void *context, const char *host, const char *verification_name,
    const char *servername, int32_t port, int32_t reject_unauthorized, const unsigned char *alpn,
    size_t alpn_length, char **error);
void *tsonic_node_tls_server_create(void *context, const unsigned char *alpn, size_t alpn_length,
    int32_t request_certificate, int32_t reject_unauthorized, char **error);
void tsonic_node_tls_server_free(void *value);
void *tsonic_node_tls_server_accept(void *server, int32_t descriptor, char **error);
int tsonic_node_tls_progress(void *value, char **error);
int tsonic_node_tls_ready(void *value);
int tsonic_node_tls_closed(void *value);
int tsonic_node_tls_pending(void *value);
int tsonic_node_tls_peek(void *value, char **error);
int64_t tsonic_node_tls_write(void *value, const uint8_t *bytes, size_t length, char **error);
int64_t tsonic_node_tls_read(void *value, uint8_t *bytes, size_t capacity, char **error);
int32_t tsonic_node_tls_end(void *value, char **error);
int32_t tsonic_node_tls_finish_response(void *value, char **error);
void tsonic_node_tls_destroy(void *value);
void tsonic_node_tls_socket_free(void *value);
int32_t tsonic_node_tls_authorized(void *value);
const char *tsonic_node_tls_authorization_error(void *value);
const char *tsonic_node_tls_servername(void *value);
const char *tsonic_node_tls_alpn(void *value);
uint64_t tsonic_node_tls_bytes_read(void *value);
uint64_t tsonic_node_tls_bytes_written(void *value);
uint64_t tsonic_node_tls_queued_bytes(void *value);
uint64_t tsonic_node_tls_activity_bytes(void *value);
int tsonic_node_tls_read_ended(void *value);
int tsonic_node_tls_write_ended(void *value);
int tsonic_node_tls_set_no_delay(void *value, int enabled);

#endif
