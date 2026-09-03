#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <netdb.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

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

static int connect_socket(const char *host, int32_t port, char **error) {
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
        if (descriptor >= 0 && connect(descriptor, address->ai_addr, address->ai_addrlen) == 0) break;
        if (descriptor >= 0) close(descriptor);
        descriptor = -1;
    }
    freeaddrinfo(addresses);
    if (descriptor < 0) set_error(error, "Unable to connect TLS socket");
    return descriptor;
}

static void configure_timeout(int descriptor, int32_t milliseconds) {
    if (milliseconds < 0) return;
    struct timeval timeout;
    timeout.tv_sec = milliseconds / 1000;
    timeout.tv_usec = (milliseconds % 1000) * 1000;
    (void)setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    (void)setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
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
    long verification = SSL_get_verify_result(ssl);
    socket->authorized = verification == X509_V_OK;
    if (!socket->authorized) {
        socket->authorization_error = copy_text(X509_verify_cert_error_string(verification));
    }
    const unsigned char *selected = NULL;
    unsigned int selected_length = 0u;
    SSL_get0_alpn_selected(ssl, &selected, &selected_length);
    if (selected_length != 0u) {
        socket->alpn = (char *)malloc((size_t)selected_length + 1u);
        if (socket->alpn != NULL) {
            memcpy(socket->alpn, selected, selected_length);
            socket->alpn[selected_length] = '\0';
        }
    }
    return socket;
}

void *tsonic_node_tls_connect(
    const char *host,
    const char *servername,
    int32_t port,
    int32_t reject_unauthorized,
    const char *ca_pem,
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
    SSL_CTX_set_verify(context, reject_unauthorized ? SSL_VERIFY_PEER : SSL_VERIFY_NONE, NULL);
    if (reject_unauthorized && SSL_CTX_set_default_verify_paths(context) != 1) {
        set_ssl_error(error, "Unable to load default TLS trust roots");
        SSL_CTX_free(context);
        return NULL;
    }
    if (!apply_ca_text(context, ca_pem, error)) {
        SSL_CTX_free(context);
        return NULL;
    }
    int descriptor = connect_socket(host, port, error);
    if (descriptor < 0) {
        SSL_CTX_free(context);
        return NULL;
    }
    configure_timeout(descriptor, timeout_ms);
    SSL *ssl = SSL_new(context);
    if (ssl == NULL || SSL_set_fd(ssl, descriptor) != 1 ||
        SSL_set_tlsext_host_name(ssl, servername) != 1 ||
        (reject_unauthorized && SSL_set1_host(ssl, servername) != 1) ||
        (alpn_length != 0u && SSL_set_alpn_protos(ssl, alpn, (unsigned int)alpn_length) != 0) ||
        SSL_connect(ssl) != 1) {
        set_ssl_error(error, "TLS handshake failed");
        SSL_free(ssl);
        close(descriptor);
        SSL_CTX_free(context);
        return NULL;
    }
    TsonicTlsSocket *socket = socket_from_ssl(context, ssl, descriptor, servername, 1);
    if (socket == NULL) {
        set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        close(descriptor);
        SSL_CTX_free(context);
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
    SSL_CTX_set_verify(server->context, verify, NULL);
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
    if (ssl == NULL || SSL_set_fd(ssl, descriptor) != 1 || SSL_accept(ssl) != 1) {
        set_ssl_error(error, "TLS server handshake failed");
        SSL_free(ssl);
        close(descriptor);
        return NULL;
    }
    const char *servername = SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name);
    TsonicTlsSocket *socket = socket_from_ssl(NULL, ssl, descriptor, servername, 0);
    if (socket == NULL) {
        set_error(error, "Unable to allocate TLS socket state");
        SSL_free(ssl);
        close(descriptor);
    }
    return socket;
}

int64_t tsonic_node_tls_write(
    void *value,
    const uint8_t *bytes,
    size_t length,
    char **error
) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || socket->ssl == NULL || length > INT_MAX ||
        (length != 0u && bytes == NULL) || error == NULL) return -1;
    *error = NULL;
    size_t total = 0u;
    while (total < length) {
        int written = SSL_write(socket->ssl, bytes + total, (int)(length - total));
        if (written <= 0) {
            set_ssl_error(error, "TLS write failed");
            return -1;
        }
        total += (size_t)written;
    }
    socket->bytes_written += (uint64_t)total;
    return (int64_t)total;
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
    int read = SSL_read(socket->ssl, bytes, (int)capacity);
    if (read > 0) {
        socket->bytes_read += (uint64_t)read;
        return read;
    }
    int ssl_error = SSL_get_error(socket->ssl, read);
    if (ssl_error == SSL_ERROR_ZERO_RETURN) return 0;
    if (ssl_error == SSL_ERROR_WANT_READ || ssl_error == SSL_ERROR_WANT_WRITE) return 0;
    set_ssl_error(error, "TLS read failed");
    return -1;
}

int32_t tsonic_node_tls_end(void *value, char **error) {
    TsonicTlsSocket *socket = (TsonicTlsSocket *)value;
    if (socket == NULL || error == NULL) return 0;
    *error = NULL;
    if (socket->ssl != NULL) (void)SSL_shutdown(socket->ssl);
    if (socket->descriptor >= 0) {
        close(socket->descriptor);
        socket->descriptor = -1;
    }
    return 1;
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
