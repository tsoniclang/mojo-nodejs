#define _POSIX_C_SOURCE 200809L
#include "model.h"

void *tsonic_node_tls_connect(
    const char *host,
    const char *verification_name,
    const char *servername,
    int32_t port,
    int32_t reject_unauthorized,
    const char *ca_pem,
    int32_t ca_present,
    const unsigned char *alpn,
    size_t alpn_length,
    char **error
) {
    if (error == NULL || host == NULL || servername == NULL || verification_name == NULL ||
        alpn_length > UINT_MAX || (alpn_length != 0u && alpn == NULL)) return NULL;
    *error = NULL;
    SSL_CTX *context = SSL_CTX_new(TLS_client_method());
    if (context == NULL) {
        tsonic_tls_set_ssl_error(error, "Unable to create TLS client context");
        return NULL;
    }
    SSL_CTX_set_verify(context, SSL_VERIFY_PEER, reject_unauthorized ? NULL : tsonic_tls_allow_unverified);
    if (!ca_present && SSL_CTX_set_default_verify_paths(context) != 1) {
        tsonic_tls_set_ssl_error(error, "Unable to load default TLS trust roots");
        SSL_CTX_free(context);
        return NULL;
    }
    if (!tsonic_tls_apply_ca_text(context, ca_pem, error)) {
        SSL_CTX_free(context);
        return NULL;
    }
    TsonicNetEndpoint *endpoint = tsonic_node_net_endpoint_new(host, port, 0);
    if (endpoint == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS connection endpoint");
        SSL_CTX_free(context);
        return NULL;
    }
    SSL *ssl = SSL_new(context);
    unsigned char address[sizeof(struct in6_addr)];
    int numeric = inet_pton(AF_INET, verification_name, address) == 1 || inet_pton(AF_INET6, verification_name, address) == 1;
    if (ssl == NULL ||
        (servername[0] != '\0' && SSL_set_tlsext_host_name(ssl, servername) != 1) ||
        (numeric ? X509_VERIFY_PARAM_set1_ip_asc(SSL_get0_param(ssl), verification_name) : SSL_set1_host(ssl, verification_name)) != 1 ||
        (alpn_length != 0u && SSL_set_alpn_protos(ssl, alpn, (unsigned int)alpn_length) != 0)) {
        tsonic_tls_set_ssl_error(error, "TLS handshake failed");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
        SSL_CTX_free(context);
        return NULL;
    }
    SSL_set_connect_state(ssl);
    TsonicTlsSocket *socket = tsonic_tls_socket_from_ssl(context, ssl, endpoint, servername, 1);
    if (socket == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
        SSL_CTX_free(context);
    } else {
        socket->connecting = 1;
    }
    return socket;
}
