#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include <uv.h>

int tsonic_node_socket_nonblocking(int descriptor);
int tsonic_node_tls_attach_socket(SSL *ssl, int descriptor);

typedef struct {
    SSL_CTX *context;
    unsigned char *alpn;
    unsigned int alpn_length;
} TsonicTlsServer;

typedef struct {
    SSL_CTX *context;
    SSL *ssl;
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
    int failed;
    uint64_t deadline;
    unsigned char *output;
    size_t output_length;
    size_t output_offset;
    size_t write_length;
} TsonicTlsSocket;

static char *copy_text(const char *value) {
    if (value == NULL) return NULL;
    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1u);
    if (copy != NULL) memcpy(copy, value, length + 1u);
    return copy;
}

static void set_error(char **error, const char *message) {
    if (error != NULL) *error = copy_text(message);
}

static void set_ssl_error(char **error, const char *fallback) {
    unsigned long code = ERR_get_error();
    if (code == 0u) {
        set_error(error, fallback);
        return;
    }
    char buffer[256];
    ERR_error_string_n(code, buffer, sizeof(buffer));
    set_error(error, buffer);
}

static int allow_unverified(int valid, X509_STORE_CTX *store) {
    (void)valid;
    (void)store;
    return 1;
}

static int apply_ca_text(SSL_CTX *context, const char *pem, char **error) {
    if (pem == NULL || pem[0] == '\0') return 1;
    BIO *bio = BIO_new_mem_buf(pem, -1);
    if (bio == NULL) {
        set_ssl_error(error, "Unable to read TLS certificate authority data");
        return 0;
    }
    X509_STORE *store = SSL_CTX_get_cert_store(context);
    int count = 0;
    for (;;) {
        X509 *certificate = PEM_read_bio_X509(bio, NULL, NULL, NULL);
        if (certificate == NULL) break;
        if (X509_STORE_add_cert(store, certificate) == 1) count += 1;
        X509_free(certificate);
        ERR_clear_error();
    }
    BIO_free(bio);
    if (count == 0) {
        set_error(error, "TLS certificate authority data contains no certificate");
        return 0;
    }
    return 1;
}

static int apply_certificate(
    SSL_CTX *context,
    const char *certificate_pem,
    const char *key_pem,
    char **error
) {
    if (certificate_pem == NULL || key_pem == NULL ||
        certificate_pem[0] == '\0' || key_pem[0] == '\0') {
        set_error(error, "TLS server requires non-empty cert and key values");
        return 0;
    }
    BIO *certificate_bio = BIO_new_mem_buf(certificate_pem, -1);
    BIO *key_bio = BIO_new_mem_buf(key_pem, -1);
    if (certificate_bio == NULL || key_bio == NULL) {
        BIO_free(certificate_bio);
        BIO_free(key_bio);
        set_ssl_error(error, "Unable to read TLS server identity");
        return 0;
    }
    X509 *certificate = PEM_read_bio_X509(certificate_bio, NULL, NULL, NULL);
    EVP_PKEY *key = PEM_read_bio_PrivateKey(key_bio, NULL, NULL, NULL);
    BIO_free(certificate_bio);
    BIO_free(key_bio);
    if (certificate == NULL || key == NULL ||
        SSL_CTX_use_certificate(context, certificate) != 1 ||
        SSL_CTX_use_PrivateKey(context, key) != 1 ||
        SSL_CTX_check_private_key(context) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(key);
        set_ssl_error(error, "TLS server certificate and key do not form a valid identity");
        return 0;
    }
    X509_free(certificate);
    EVP_PKEY_free(key);
    return 1;
}

static int connect_socket(const char *host, int32_t port, int *pending, char **error) {
    if (host == NULL || host[0] == '\0' || port < 0 || port > 65535) {
        set_error(error, "TLS host and port are invalid");
        return -1;
    }
    char service[16];
    snprintf(service, sizeof(service), "%d", port);
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    int status = getaddrinfo(host, service, &hints, &addresses);
    if (status != 0) {
        set_error(error, gai_strerror(status));
        return -1;
    }
    int descriptor = -1;
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        descriptor = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (descriptor >= 0 && tsonic_node_socket_nonblocking(descriptor) == 0) {
            int result = connect(descriptor, address->ai_addr, address->ai_addrlen);
            if (result == 0 || errno == EINPROGRESS) {
                *pending = result != 0;
                break;
            }
        }
        if (descriptor >= 0) close(descriptor);
        descriptor = -1;
    }
    freeaddrinfo(addresses);
    if (descriptor < 0) set_error(error, "Unable to connect TLS socket");
    return descriptor;
}

static TsonicTlsSocket *socket_from_ssl(
    SSL_CTX *context,
    SSL *ssl,
    int descriptor,
    const char *servername,
    int context_owned
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)calloc(1u, sizeof(*socket));
    if (socket == NULL) return NULL;
    socket->context = context_owned ? context : NULL;
    socket->ssl = ssl;
    socket->descriptor = descriptor;
    socket->referenced = 1;
    socket->servername = copy_text(servername == NULL ? "" : servername);
    if (socket->servername == NULL) {
        free(socket);
        return NULL;
    }
    SSL_set_mode(ssl, SSL_MODE_ENABLE_PARTIAL_WRITE | SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER);
    SSL_set_options(ssl, SSL_OP_NO_RENEGOTIATION);
    return socket;
}

static int complete_handshake(TsonicTlsSocket *socket, char **error) {
    long verification = SSL_get_verify_result(socket->ssl);
    socket->authorized = SSL_get0_peer_certificate(socket->ssl) != NULL && verification == X509_V_OK;
    if (!socket->authorized) {
        socket->authorization_error = copy_text(verification == X509_V_OK ? "TLS peer did not provide a certificate" : X509_verify_cert_error_string(verification));
        if (socket->authorization_error == NULL) {
            set_error(error, "Unable to retain TLS verification result");
            return 0;
        }
    }
    const unsigned char *selected = NULL;
    unsigned int selected_length = 0u;
    SSL_get0_alpn_selected(socket->ssl, &selected, &selected_length);
    if (selected_length != 0u) {
        socket->alpn = (char *)malloc((size_t)selected_length + 1u);
        if (socket->alpn == NULL) {
            set_error(error, "Unable to allocate negotiated ALPN protocol");
            return 0;
        }
        memcpy(socket->alpn, selected, selected_length);
        socket->alpn[selected_length] = '\0';
    }
    const char *servername = SSL_get_servername(socket->ssl, TLSEXT_NAMETYPE_host_name);
    if (servername != NULL) {
        char *name = copy_text(servername);
        if (name == NULL) {
            set_error(error, "Unable to allocate negotiated TLS server name");
            return 0;
        }
        free(socket->servername);
        socket->servername = name;
    }
    socket->ready = 1;
    return 1;
}

void *tsonic_node_tls_connect(
    const char *host,
    const char *servername,
    int32_t port,
    int32_t reject_unauthorized,
    const char *ca_pem,
    int32_t ca_present,
    const unsigned char *alpn,
    size_t alpn_length,
    int32_t timeout_ms,
    char **error
) {
    if (error == NULL || alpn_length > UINT_MAX) return NULL;
    *error = NULL;
    SSL_CTX *context = SSL_CTX_new(TLS_client_method());
    if (context == NULL) {
        set_ssl_error(error, "Unable to create TLS client context");
        return NULL;
    }
    SSL_CTX_set_verify(context, SSL_VERIFY_PEER, reject_unauthorized ? NULL : allow_unverified);
    if (!ca_present && SSL_CTX_set_default_verify_paths(context) != 1) {
        set_ssl_error(error, "Unable to load default TLS trust roots");
        SSL_CTX_free(context);
        return NULL;
    }
    if (!apply_ca_text(context, ca_pem, error)) {
        SSL_CTX_free(context);
        return NULL;
    }
    int pending = 0;
    int descriptor = connect_socket(host, port, &pending, error);
    if (descriptor < 0) {
        SSL_CTX_free(context);
        return NULL;
    }
    SSL *ssl = SSL_new(context);
    unsigned char address[sizeof(struct in6_addr)];
    int numeric = inet_pton(AF_INET, servername, address) == 1 || inet_pton(AF_INET6, servername, address) == 1;
    if (ssl == NULL || tsonic_node_tls_attach_socket(ssl, descriptor) != 1 ||
        (!numeric && servername[0] != '\0' && SSL_set_tlsext_host_name(ssl, servername) != 1) ||
        (numeric ? X509_VERIFY_PARAM_set1_ip_asc(SSL_get0_param(ssl), servername) : SSL_set1_host(ssl, servername)) != 1 ||
        (alpn_length != 0u && SSL_set_alpn_protos(ssl, alpn, (unsigned int)alpn_length) != 0)) {
        set_ssl_error(error, "TLS handshake failed");
        SSL_free(ssl);
        close(descriptor);
        SSL_CTX_free(context);
        return NULL;
    }
    SSL_set_connect_state(ssl);
    TsonicTlsSocket *socket = socket_from_ssl(context, ssl, descriptor, servername, 1);
    if (socket == NULL) {
        set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        close(descriptor);
        SSL_CTX_free(context);
    } else {
        socket->connecting = pending;
        socket->deadline = timeout_ms > 0 ? uv_hrtime() + (uint64_t)timeout_ms * 1000000u : 0u;
    }
    return socket;
}

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
        !apply_certificate(server->context, certificate_pem, key_pem, error) ||
        !apply_ca_text(server->context, ca_pem, error)) {
        if (server->context != NULL) SSL_CTX_free(server->context);
        free(server);
        return NULL;
    }
    int verify = request_certificate ? SSL_VERIFY_PEER : SSL_VERIFY_NONE;
    if (request_certificate && reject_unauthorized) verify |= SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
    SSL_CTX_set_verify(server->context, verify, reject_unauthorized ? NULL : allow_unverified);
    if (alpn_length != 0u) {
        server->alpn = (unsigned char *)malloc(alpn_length);
        if (server->alpn == NULL) {
            set_error(error, "Unable to allocate TLS ALPN configuration");
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
    if (server == NULL || descriptor < 0 || error == NULL) return NULL;
    *error = NULL;
    SSL *ssl = SSL_new(server->context);
    if (ssl == NULL || tsonic_node_socket_nonblocking(descriptor) < 0 || tsonic_node_tls_attach_socket(ssl, descriptor) != 1) {
        set_ssl_error(error, "TLS server handshake failed");
        SSL_free(ssl);
        close(descriptor);
        return NULL;
    }
    SSL_set_accept_state(ssl);
    TsonicTlsSocket *socket = socket_from_ssl(NULL, ssl, descriptor, "", 0);
    if (socket == NULL) {
        set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        close(descriptor);
    }
    return socket;
}

int tsonic_node_tls_progress(void *value, char **error) {
    TsonicTlsSocket *socket = value;
    if (error == NULL) return -1;
    *error = NULL;
    if (socket == NULL || socket->failed) {
        set_error(error, "TLS connection has failed");
        return -1;
    }
    if (socket->descriptor < 0) return 0;
    if (!socket->ready) {
        if (socket->deadline != 0u && uv_hrtime() >= socket->deadline) {
            set_error(error, "TLS connection handshake timed out");
            goto failed;
        }
        if (socket->connecting) {
            struct pollfd request = {socket->descriptor, POLLOUT, 0};
            int polled = poll(&request, 1u, 0);
            if (polled == 0 || (polled < 0 && errno == EINTR)) return 0;
            int status = 0;
            socklen_t length = sizeof(status);
            if (polled < 0 || getsockopt(socket->descriptor, SOL_SOCKET, SO_ERROR, &status, &length) < 0 || status != 0) {
                set_error(error, "Unable to connect TLS socket");
                goto failed;
            }
            socket->connecting = 0;
        }
        ERR_clear_error();
        int result = SSL_do_handshake(socket->ssl);
        if (result != 1) {
            int reason = SSL_get_error(socket->ssl, result);
            if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return 0;
            set_ssl_error(error, "TLS handshake failed");
            goto failed;
        }
        if (!complete_handshake(socket, error)) goto failed;
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
            set_ssl_error(error, "TLS write failed");
            goto failed;
        }
        socket->output_offset += (size_t)written;
        socket->bytes_written += (uint64_t)written;
        progressed += (size_t)written;
        socket->write_length = 0u;
    }
    if (socket->output_offset == socket->output_length) {
        free(socket->output);
        socket->output = NULL;
        socket->output_offset = socket->output_length = 0u;
        if (socket->ending) {
            ERR_clear_error();
            int result = SSL_shutdown(socket->ssl);
            if (result < 0) {
                int reason = SSL_get_error(socket->ssl, result);
                if (reason == SSL_ERROR_WANT_READ || reason == SSL_ERROR_WANT_WRITE) return 1;
                set_ssl_error(error, "TLS shutdown failed");
                goto failed;
            }
            close(socket->descriptor);
            socket->descriptor = -1;
        }
    }
    return 1;
failed:
    socket->failed = 1;
    close(socket->descriptor);
    socket->descriptor = -1;
    return -1;
}

int tsonic_node_tls_ready(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && socket->ready && !socket->failed;
}

int tsonic_node_tls_closed(void *value) {
    TsonicTlsSocket *socket = value;
    return socket == NULL || socket->descriptor < 0;
}

int tsonic_node_tls_pending(void *value) {
    TsonicTlsSocket *socket = value;
    return socket != NULL && socket->descriptor >= 0 &&
        (!socket->ready || socket->output_length != 0u || socket->ending);
}

int64_t tsonic_node_tls_write(
    void *value,
    const uint8_t *bytes,
    size_t length,
    char **error
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || socket->ssl == NULL || socket->ending || socket->descriptor < 0 ||
        (length != 0u && bytes == NULL) || error == NULL) return -1;
    *error = NULL;
    size_t retained = socket->output_length - socket->output_offset;
    if (length > 268435456u - retained) {
        set_error(error, "TLS queued writes exceed the byte budget");
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
        set_error(error, "Unable to allocate queued TLS write");
        return -1;
    }
    memcpy(output + socket->output_length, bytes, length);
    socket->output = output;
    socket->output_length += length;
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
    if (socket->descriptor < 0) return 0;
    if (!socket->ready || socket->write_length != 0u) return -2;
    ERR_clear_error();
    int read = SSL_read(socket->ssl, bytes, (int)capacity);
    if (read > 0) {
        socket->bytes_read += (uint64_t)read;
        return read;
    }
    int ssl_error = SSL_get_error(socket->ssl, read);
    if (ssl_error == SSL_ERROR_ZERO_RETURN) return 0;
    if (ssl_error == SSL_ERROR_WANT_READ || ssl_error == SSL_ERROR_WANT_WRITE) return -2;
    set_ssl_error(error, "TLS read failed");
    socket->failed = 1;
    close(socket->descriptor);
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

void tsonic_node_tls_destroy(void *value) {
    TsonicTlsSocket *socket = value;
    if (socket == NULL) return;
    if (socket->descriptor >= 0) close(socket->descriptor);
    socket->descriptor = -1;
    socket->ending = 1;
    free(socket->output);
    socket->output = NULL;
    socket->output_length = socket->output_offset = socket->write_length = 0u;
}

void tsonic_node_tls_socket_free(void *value) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL) return;
    if (socket->ssl != NULL) SSL_free(socket->ssl);
    if (socket->descriptor >= 0) close(socket->descriptor);
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
