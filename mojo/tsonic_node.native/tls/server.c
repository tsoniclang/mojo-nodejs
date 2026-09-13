#define _POSIX_C_SOURCE 200809L
#include "model.h"

int tsonic_tls_select_alpn(
    SSL *ssl,
    const unsigned char **output,
    unsigned char *output_length,
    const unsigned char *input,
    unsigned int input_length,
    void *opaque
) {
    (void)opaque;
    TsonicTlsSocket *socket = SSL_get_app_data(ssl);
    if (socket == NULL || socket->offered_alpn_length == 0u) return SSL_TLSEXT_ERR_NOACK;
    return SSL_select_next_proto(
        (unsigned char **)output,
        output_length,
        socket->offered_alpn,
        socket->offered_alpn_length,
        input,
        input_length
    ) == OPENSSL_NPN_NEGOTIATED ? SSL_TLSEXT_ERR_OK : SSL_TLSEXT_ERR_NOACK;
}

void *tsonic_node_tls_server_create(
    void *context_value,
    const unsigned char *alpn,
    size_t alpn_length,
    int32_t request_certificate,
    int32_t reject_unauthorized,
    char **error
) {
    if (error == NULL || context_value == NULL || alpn_length > UINT_MAX || (alpn_length != 0u && alpn == NULL)) return NULL;
    *error = NULL;
    TsonicTlsServer *server = (TsonicTlsServer *)calloc(1u, sizeof(*server));
    if (server == NULL) return NULL;
    server->context = context_value;
    if (SSL_CTX_get0_certificate(server->context) == NULL || SSL_CTX_get0_privatekey(server->context) == NULL) {
        tsonic_tls_set_error(error, "TLS server requires a certificate and private key identity");
        free(server);
        return NULL;
    }
    if (SSL_CTX_up_ref(server->context) != 1) {
        tsonic_tls_set_ssl_error(error, "Unable to retain TLS server context");
        free(server);
        return NULL;
    }
    server->request_certificate = request_certificate;
    server->reject_unauthorized = reject_unauthorized;
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
    int verify = server->request_certificate ? SSL_VERIFY_PEER : SSL_VERIFY_NONE;
    if (server->request_certificate && server->reject_unauthorized) verify |= SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
    SSL_set_verify(ssl, verify, server->reject_unauthorized ? NULL : tsonic_tls_allow_unverified);
    TsonicTlsSocket *socket = tsonic_tls_socket_from_ssl(ssl, endpoint, "");
    if (socket == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
    } else if (server->alpn_length != 0u) {
        socket->offered_alpn = malloc(server->alpn_length);
        if (socket->offered_alpn == NULL) {
            tsonic_tls_set_error(error, "Unable to retain TLS server ALPN configuration");
            tsonic_node_tls_socket_free(socket);
            return NULL;
        }
        memcpy(socket->offered_alpn, server->alpn, server->alpn_length);
        socket->offered_alpn_length = server->alpn_length;
    }
    return socket;
}
