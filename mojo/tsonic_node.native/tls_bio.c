#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <stdint.h>
#include <stdlib.h>
#include <uv.h>

int64_t tsonic_node_socket_read(int descriptor, void *bytes, size_t capacity);
int64_t tsonic_node_socket_write(int descriptor, const void *bytes, size_t length);

typedef struct {
    int descriptor;
} SocketBio;

static BIO_METHOD *socket_method;
static uv_once_t initialized = UV_ONCE_INIT;

static int create(BIO *bio) {
    BIO_set_init(bio, 0);
    BIO_set_data(bio, NULL);
    BIO_set_shutdown(bio, BIO_NOCLOSE);
    return 1;
}

static int destroy(BIO *bio) {
    if (bio == NULL) return 0;
    free(BIO_get_data(bio));
    BIO_set_data(bio, NULL);
    BIO_set_init(bio, 0);
    return 1;
}

static int read_bytes(BIO *bio, char *bytes, int length) {
    BIO_clear_retry_flags(bio);
    SocketBio *socket = BIO_get_data(bio);
    if (socket == NULL || bytes == NULL || length < 0) return -1;
    int64_t result = tsonic_node_socket_read(socket->descriptor, bytes, (size_t)length);
    if (result == -2) {
        BIO_set_retry_read(bio);
        return -1;
    }
    return (int)result;
}

static int write_bytes(BIO *bio, const char *bytes, int length) {
    BIO_clear_retry_flags(bio);
    SocketBio *socket = BIO_get_data(bio);
    if (socket == NULL || bytes == NULL || length < 0) return -1;
    int64_t result = tsonic_node_socket_write(socket->descriptor, bytes, (size_t)length);
    if (result == -2) {
        BIO_set_retry_write(bio);
        return -1;
    }
    return (int)result;
}

static long control(BIO *bio, int command, long argument, void *pointer) {
    SocketBio *socket = BIO_get_data(bio);
    switch (command) {
        case BIO_C_GET_FD:
            if (socket == NULL) return -1;
            if (pointer != NULL) *(int *)pointer = socket->descriptor;
            return socket->descriptor;
        case BIO_CTRL_GET_CLOSE:
            return BIO_NOCLOSE;
        case BIO_CTRL_SET_CLOSE:
            return argument == BIO_NOCLOSE;
        case BIO_CTRL_FLUSH:
            return 1;
        default:
            return 0;
    }
}

static void initialize(void) {
    int index = BIO_get_new_index();
    if (index < 0) return;
    BIO_METHOD *method = BIO_meth_new(index | BIO_TYPE_SOURCE_SINK | BIO_TYPE_DESCRIPTOR, "Tsonic nonblocking socket");
    if (method == NULL) return;
    if (BIO_meth_set_create(method, create) != 1 ||
        BIO_meth_set_destroy(method, destroy) != 1 ||
        BIO_meth_set_read(method, read_bytes) != 1 ||
        BIO_meth_set_write(method, write_bytes) != 1 ||
        BIO_meth_set_ctrl(method, control) != 1) {
        BIO_meth_free(method);
        return;
    }
    socket_method = method;
}

int tsonic_node_tls_attach_socket(SSL *ssl, int descriptor) {
    if (ssl == NULL || descriptor < 0) return 0;
    uv_once(&initialized, initialize);
    if (socket_method == NULL) return 0;
    BIO *bio = BIO_new(socket_method);
    if (bio == NULL) return 0;
    SocketBio *socket = malloc(sizeof(*socket));
    if (socket == NULL) {
        BIO_free(bio);
        return 0;
    }
    socket->descriptor = descriptor;
    BIO_set_data(bio, socket);
    BIO_set_init(bio, 1);
    SSL_set_bio(ssl, bio, bio);
    return 1;
}
