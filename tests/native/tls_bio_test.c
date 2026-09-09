#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <openssl/ssl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

int tsonic_node_tls_attach_socket(SSL *ssl, int descriptor);

static void retry_and_ownership(void) {
    int descriptors[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, descriptors) == 0);
    int capacity = 4096;
    assert(setsockopt(descriptors[0], SOL_SOCKET, SO_SNDBUF, &capacity, sizeof(capacity)) == 0);
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    assert(context != NULL);
    SSL *ssl = SSL_new(context);
    assert(ssl != NULL && tsonic_node_tls_attach_socket(ssl, descriptors[0]));
    assert(SSL_get_fd(ssl) == descriptors[0]);
    BIO *bio = SSL_get_rbio(ssl);
    char bytes[16384];
    memset(bytes, 23, sizeof(bytes));
    assert(BIO_read(bio, bytes, sizeof(bytes)) < 0);
    assert(BIO_should_read(bio) && BIO_should_retry(bio));
    assert(write(descriptors[1], "hello", 5) == 5);
    assert(BIO_read(bio, bytes, 5) == 5 && memcmp(bytes, "hello", 5) == 0);
    assert(!BIO_should_retry(bio));
    int blocked = 0;
    for (int attempt = 0; attempt < 256; attempt++) {
        int count = BIO_write(bio, bytes, sizeof(bytes));
        if (count < 0) {
            assert(BIO_should_write(bio) && BIO_should_retry(bio));
            blocked = 1;
            break;
        }
        assert(count > 0);
    }
    assert(blocked);
    SSL_free(ssl);
    SSL_CTX_free(context);
    assert(fcntl(descriptors[0], F_GETFD) >= 0);
    close(descriptors[0]);
    close(descriptors[1]);
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
    SSL *ssl = SSL_new(context);
    assert(ssl != NULL && tsonic_node_tls_attach_socket(ssl, descriptors[0]));
    close(descriptors[1]);
    BIO *bio = SSL_get_wbio(ssl);
    assert(BIO_write(bio, "closed", 6) < 0);
    assert(!BIO_should_retry(bio));
    assert(sigaction(SIGPIPE, NULL, &action) == 0 && action.sa_handler == SIG_DFL);
    SSL_free(ssl);
    SSL_CTX_free(context);
    close(descriptors[0]);
}

int main(void) {
    retry_and_ownership();
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
