#define _POSIX_C_SOURCE 200809L
#include "model.h"

TsonicTlsSocket *tsonic_tls_socket_from_ssl(
    SSL *ssl,
    TsonicNetEndpoint *endpoint,
    const char *servername
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)calloc(1u, sizeof(*socket));
    if (socket == NULL) return NULL;
    socket->ssl = ssl;
    socket->endpoint = endpoint;
    socket->descriptor = tsonic_node_net_endpoint_descriptor(endpoint);
    socket->referenced = 1;
    socket->servername = tsonic_tls_copy_text(servername == NULL ? "" : servername);
    if (socket->servername == NULL) {
        free(socket);
        return NULL;
    }
    SSL_set_mode(ssl, SSL_MODE_ENABLE_PARTIAL_WRITE | SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER);
    SSL_set_options(ssl, SSL_OP_NO_RENEGOTIATION);
    SSL_set_app_data(ssl, socket);
    return socket;
}

int tsonic_tls_complete_handshake(TsonicTlsSocket *socket, char **error) {
    long verification = SSL_get_verify_result(socket->ssl);
    socket->authorized = SSL_get0_peer_certificate(socket->ssl) != NULL && verification == X509_V_OK;
    if (!socket->authorized) {
        socket->authorization_error = tsonic_tls_copy_text(verification == X509_V_OK ? "TLS peer did not provide a certificate" : X509_verify_cert_error_string(verification));
        if (socket->authorization_error == NULL) {
            tsonic_tls_set_error(error, "Unable to retain TLS verification result");
            return 0;
        }
    }
    const unsigned char *selected = NULL;
    unsigned int selected_length = 0u;
    SSL_get0_alpn_selected(socket->ssl, &selected, &selected_length);
    if (selected_length != 0u) {
        socket->alpn = (char *)malloc((size_t)selected_length + 1u);
        if (socket->alpn == NULL) {
            tsonic_tls_set_error(error, "Unable to allocate negotiated ALPN protocol");
            return 0;
        }
        memcpy(socket->alpn, selected, selected_length);
        socket->alpn[selected_length] = '\0';
    }
    const char *servername = SSL_get_servername(socket->ssl, TLSEXT_NAMETYPE_host_name);
    if (servername != NULL) {
        char *name = tsonic_tls_copy_text(servername);
        if (name == NULL) {
            tsonic_tls_set_error(error, "Unable to allocate negotiated TLS server name");
            return 0;
        }
        free(socket->servername);
        socket->servername = name;
    }
    socket->ready = 1;
    return 1;
}
