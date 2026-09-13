#define _POSIX_C_SOURCE 200809L
#include "model.h"

void *tsonic_node_tls_connect(
    void *context_value,
    const char *host,
    const char *verification_name,
    const char *servername,
    int32_t port,
    int32_t reject_unauthorized,
    const unsigned char *alpn,
    size_t alpn_length,
    char **error
) {
    if (error == NULL || context_value == NULL || host == NULL || servername == NULL || verification_name == NULL ||
        alpn_length > UINT_MAX || (alpn_length != 0u && alpn == NULL)) return NULL;
    *error = NULL;
    SSL_CTX *context = context_value;
    TsonicNetEndpoint *endpoint = tsonic_node_net_endpoint_new(host, port, 0, 511);
    if (endpoint == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS connection endpoint");
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
        return NULL;
    }
    SSL_set_verify(ssl, SSL_VERIFY_PEER, reject_unauthorized ? NULL : tsonic_tls_allow_unverified);
    SSL_set_connect_state(ssl);
    TsonicTlsSocket *socket = tsonic_tls_socket_from_ssl(ssl, endpoint, servername);
    if (socket == NULL) {
        tsonic_tls_set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        tsonic_node_net_endpoint_free(endpoint);
    } else {
        socket->connecting = 1;
    }
    return socket;
}
