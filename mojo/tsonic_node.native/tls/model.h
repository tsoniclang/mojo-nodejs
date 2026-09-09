#ifndef TSONIC_NODE_TLS_MODEL_H
#define TSONIC_NODE_TLS_MODEL_H

#include "../net/endpoint.h"
#include "api.h"
#include <arpa/inet.h>
#include <errno.h>
#include <limits.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <uv.h>

typedef struct {
    SSL_CTX *context;
    unsigned char *alpn;
    unsigned int alpn_length;
} TsonicTlsServer;

typedef struct {
    SSL_CTX *context;
    SSL *ssl;
    TsonicNetEndpoint *endpoint;
    int descriptor;
    int authorized;
    int referenced;
    uint64_t bytes_read;
    uint64_t bytes_written;
    char *authorization_error;
    char *servername;
    char *alpn;
    int connecting;
    int ready;
    int ending;
    int read_ended;
    int write_ended;
    int close_after_flush;
    int failed;
    unsigned char *output;
    size_t output_length;
    size_t output_offset;
    size_t write_length;
} TsonicTlsSocket;

char *tsonic_tls_copy_text(const char *value);
void tsonic_tls_set_error(char **error, const char *message);
void tsonic_tls_set_ssl_error(char **error, const char *fallback);
int tsonic_tls_allow_unverified(int valid, X509_STORE_CTX *store);
int tsonic_tls_apply_ca_text(SSL_CTX *context, const char *pem, char **error);
int tsonic_tls_apply_certificate(SSL_CTX *context, const char *certificate_pem, const char *key_pem, char **error);
TsonicTlsSocket *tsonic_tls_socket_from_ssl(SSL_CTX *context, SSL *ssl, TsonicNetEndpoint *endpoint, const char *servername, int context_owned);
int tsonic_tls_complete_handshake(TsonicTlsSocket *socket, char **error);
int tsonic_node_tls_attach_socket(SSL *ssl, int descriptor);

#endif
