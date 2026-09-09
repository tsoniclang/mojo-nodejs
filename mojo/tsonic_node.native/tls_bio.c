#define _POSIX_C_SOURCE 200809L
#include "tls/model.h"

int64_t tsonic_node_socket_read(int descriptor, void *bytes, size_t capacity);
int64_t tsonic_node_socket_write(int descriptor, const void *bytes, size_t length);

int tsonic_tls_initialize_transport(SSL *ssl) {
    if (ssl == NULL || SSL_get_rbio(ssl) != NULL || SSL_get_wbio(ssl) != NULL) return 0;
    BIO *input = BIO_new(BIO_s_mem());
    BIO *output = BIO_new(BIO_s_mem());
    if (input == NULL || output == NULL) {
        BIO_free(input);
        BIO_free(output);
        return 0;
    }
    BIO_set_mem_eof_return(input, -1);
    SSL_set_bio(ssl, input, output);
    return 1;
}

int tsonic_tls_pump_transport(TsonicTlsSocket *socket, char **error) {
    if (socket == NULL || socket->ssl == NULL || socket->descriptor < 0 || error == NULL) return 0;
    BIO *input = SSL_get_rbio(socket->ssl);
    BIO *output = SSL_get_wbio(socket->ssl);
    if (input == NULL || output == NULL) {
        tsonic_tls_set_error(error, "TLS transport buffers are absent");
        return 0;
    }
    if (BIO_ctrl_pending(input) > 65536u || BIO_ctrl_pending(output) > 16777216u) {
        tsonic_tls_set_error(error, "TLS transport exceeds its encrypted buffer budget");
        return 0;
    }
    unsigned char bytes[16384];
    size_t received = 0u;
    while (!socket->transport_read_ended && received < 65536u) {
        size_t retained = BIO_ctrl_pending(input);
        size_t capacity = 65536u - retained;
        if (capacity == 0u) break;
        if (capacity > sizeof(bytes)) capacity = sizeof(bytes);
        int64_t count = tsonic_node_socket_read(socket->descriptor, bytes, capacity);
        if (count == -2) break;
        if (count < 0) {
            tsonic_tls_set_error(error, "Unable to receive encrypted TLS data");
            return 0;
        }
        if (count == 0) {
            socket->transport_read_ended = 1;
            BIO_set_mem_eof_return(input, 0);
            break;
        }
        if (BIO_write(input, bytes, (int)count) != count) {
            tsonic_tls_set_error(error, "Unable to retain encrypted TLS input");
            return 0;
        }
        received += (size_t)count;
        socket->wire_bytes_read += (uint64_t)count;
    }
    size_t sent = 0u;
    while (sent < 65536u) {
        char *pending = NULL;
        long available = BIO_get_mem_data(output, &pending);
        if (available <= 0) break;
        size_t length = (size_t)available;
        if (length > sizeof(bytes)) length = sizeof(bytes);
        int64_t count = tsonic_node_socket_write(socket->descriptor, pending, length);
        if (count == -2) break;
        if (count <= 0) {
            tsonic_tls_set_error(error, "Unable to transmit encrypted TLS data");
            return 0;
        }
        if (BIO_read(output, bytes, (int)count) != count) {
            tsonic_tls_set_error(error, "Unable to consume transmitted TLS output");
            return 0;
        }
        sent += (size_t)count;
        socket->wire_bytes_written += (uint64_t)count;
    }
    return 1;
}
