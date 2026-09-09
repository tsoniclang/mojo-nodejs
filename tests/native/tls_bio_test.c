#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/tls/model.h"
#include <assert.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/wait.h>

static void buffered_duplex_and_ownership(void) {
    int descriptors[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, descriptors) == 0);
    int capacity = 4096;
    assert(setsockopt(descriptors[0], SOL_SOCKET, SO_SNDBUF, &capacity, sizeof(capacity)) == 0);
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    assert(context != NULL);
    TsonicTlsSocket socket = {0};
    socket.ssl = SSL_new(context);
    socket.descriptor = descriptors[0];
    assert(socket.ssl != NULL && tsonic_tls_initialize_transport(socket.ssl));
    assert(!tsonic_tls_initialize_transport(socket.ssl));
    BIO *input = SSL_get_rbio(socket.ssl);
    BIO *output = SSL_get_wbio(socket.ssl);
    assert(input != output);
    char bytes[16384];
    memset(bytes, 23, sizeof(bytes));
    assert(BIO_read(input, bytes, sizeof(bytes)) < 0);
    assert(BIO_should_read(input) && BIO_should_retry(input));
    char *error = NULL;
    assert(tsonic_tls_pump_transport(&socket, &error) && error == NULL);
    int blocked = 0;
    for (int attempt = 0; attempt < 256; attempt++) {
        assert(BIO_write(output, bytes, sizeof(bytes)) == sizeof(bytes));
        assert(tsonic_tls_pump_transport(&socket, &error) && error == NULL);
        if (BIO_ctrl_pending(output) != 0u) {
            blocked = 1;
            break;
        }
    }
    assert(blocked);
    assert(write(descriptors[1], "hello", 5) == 5);
    assert(tsonic_tls_pump_transport(&socket, &error) && error == NULL);
    assert(BIO_ctrl_pending(output) != 0u);
    assert(BIO_read(input, bytes, 5) == 5 && memcmp(bytes, "hello", 5) == 0);
    assert(socket.wire_bytes_read == 5u && socket.wire_bytes_written > 0u);
    SSL_free(socket.ssl);
    SSL_CTX_free(context);
    assert(fcntl(descriptors[0], F_GETFD) >= 0);
    close(descriptors[0]);
    close(descriptors[1]);
}

static void input_budget_and_eof(void) {
    int descriptors[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, descriptors) == 0);
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    assert(context != NULL);
    TsonicTlsSocket socket = {0};
    socket.ssl = SSL_new(context);
    socket.descriptor = descriptors[0];
    assert(socket.ssl != NULL && tsonic_tls_initialize_transport(socket.ssl));
    char bytes[4096] = {0};
    char *error = NULL;
    for (int index = 0; index < 17; index++) {
        assert(write(descriptors[1], bytes, sizeof(bytes)) == sizeof(bytes));
        assert(tsonic_tls_pump_transport(&socket, &error) && error == NULL);
        assert(BIO_ctrl_pending(SSL_get_rbio(socket.ssl)) <= 65536u);
    }
    assert(BIO_ctrl_pending(SSL_get_rbio(socket.ssl)) == 65536u);
    assert(socket.wire_bytes_read == 65536u);
    close(descriptors[1]);
    for (int index = 0; index < 16; index++) {
        assert(BIO_read(SSL_get_rbio(socket.ssl), bytes, sizeof(bytes)) == sizeof(bytes));
    }
    assert(tsonic_tls_pump_transport(&socket, &error) && error == NULL);
    assert(socket.transport_read_ended);
    assert(BIO_read(SSL_get_rbio(socket.ssl), bytes, sizeof(bytes)) == sizeof(bytes));
    assert(BIO_read(SSL_get_rbio(socket.ssl), bytes, sizeof(bytes)) == 0);
    SSL_free(socket.ssl);
    SSL_CTX_free(context);
    close(descriptors[0]);
}

static void disconnected_peer(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = SIG_DFL;
    assert(sigemptyset(&action.sa_mask) == 0);
    assert(sigaction(SIGPIPE, &action, NULL) == 0);
    int descriptors[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, descriptors) == 0);
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    assert(context != NULL);
    TsonicTlsSocket socket = {0};
    socket.ssl = SSL_new(context);
    socket.descriptor = descriptors[0];
    assert(socket.ssl != NULL && tsonic_tls_initialize_transport(socket.ssl));
    close(descriptors[1]);
    assert(BIO_write(SSL_get_wbio(socket.ssl), "closed", 6) == 6);
    char *error = NULL;
    assert(!tsonic_tls_pump_transport(&socket, &error));
    assert(error != NULL);
    free(error);
    assert(sigaction(SIGPIPE, NULL, &action) == 0 && action.sa_handler == SIG_DFL);
    SSL_free(socket.ssl);
    SSL_CTX_free(context);
    close(descriptors[0]);
}

int main(void) {
    buffered_duplex_and_ownership();
    input_budget_and_eof();
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        disconnected_peer();
        _exit(0);
    }
    int status;
    assert(waitpid(child, &status, 0) == child);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    return 0;
}
