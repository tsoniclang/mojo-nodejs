#define _POSIX_C_SOURCE 200809L
#include "model.h"

static int select_alpn(
    SSL *ssl,
    const unsigned char **output,
    unsigned char *output_length,
    const unsigned char *input,
    unsigned int input_length,
    void *opaque
) {
    (void)ssl;
    TsonicTlsServer *server = (TsonicTlsServer *)opaque;
    if (server->alpn_length == 0u) return SSL_TLSEXT_ERR_NOACK;
    return SSL_select_next_proto(
        (unsigned char **)output,
        output_length,
        server->alpn,
        server->alpn_length,
        input,
        input_length
    ) == OPENSSL_NPN_NEGOTIATED ? SSL_TLSEXT_ERR_OK : SSL_TLSEXT_ERR_NOACK;
}

void *tsonic_node_tls_server_create(
    const char *key_pem,
    const char *certificate_pem,
    const char *ca_pem,
    const unsigned char *alpn,
    size_t alpn_length,
    int32_t request_certificate,
    int32_t reject_unauthorized,
    char **error
) {
    if (error == NULL || alpn_length > UINT_MAX) return NULL;
    *error = NULL;
    TsonicTlsServer *server = (TsonicTlsServer *)calloc(1u, sizeof(*server));
    if (server == NULL) return NULL;
    server->context = SSL_CTX_new(TLS_server_method());
    if (server->context == NULL ||
        !tsonic_tls_apply_certificate(server->context, certificate_pem, key_pem, error) ||
        !tsonic_tls_apply_ca_text(server->context, ca_pem, error)) {
        if (server->context != NULL) SSL_CTX_free(server->context);
        free(server);
        return NULL;
    }
    int verify = request_certificate ? SSL_VERIFY_PEER : SSL_VERIFY_NONE;
    if (request_certificate && reject_unauthorized) verify |= SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
    SSL_CTX_set_verify(server->context, verify, reject_unauthorized ? NULL : tsonic_tls_allow_unverified);
    if (alpn_length != 0u) {
        server->alpn = (unsigned char *)malloc(alpn_length);
        if (server->alpn == NULL) {
            tsonic_tls_set_error(error, "Unable to allocate TLS ALPN configuration");
            SSL_CTX_free(server->context);
            free(server);
            return NULL;
        }
        memcpy(server->alpn, alpn, alpn_length);
        server->alpn_length = (unsigned int)alpn_length;
        SSL_CTX_set_alpn_select_cb(server->context, select_alpn, server);
    }
    return server;
}

void tsonic_node_tls_server_free(void *value) {
    TsonicTlsServer *server = (TsonicTlsServer *)value;
    if (server == NULL) return;
    SSL_CTX_free(server->context);
    free(server->alpn);
    free(server);
}

void *tsonic_node_tls_server_accept(void *server_value, int32_t descriptor, char **error) {
    TsonicTlsServer *server = (TsonicTlsServer *)server_value;
    if (server == NULL || descriptor < 0 || error == NULL) {
        if (descriptor >= 0) close(descriptor);
        return NULL;
    }
    *error = NULL;
    int status = 0;
    TsonicNetEndpoint *endpoint = tsonic_node_net_endpoint_adopt(descriptor, &status);
    if (endpoint == NULL) {
        tsonic_tls_set_error(error, uv_strerror(status));
        return NULL;
    }
    SSL *ssl = SSL_new(server->context);
    if (ssl == NULL || tsonic_tls_initialize_transport(ssl) != 1) {
        tsonic_tls_set_ssl_error(error, "TLS server handshake failed");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
        return NULL;
    }
    SSL_set_accept_state(ssl);
    TsonicTlsSocket *socket = tsonic_tls_socket_from_ssl(NULL, ssl, endpoint, "", 0);
    if (socket == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
    }
    return socket;
}
