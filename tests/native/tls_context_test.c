#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/tls/model.h"
#include <openssl/pkcs12.h>
#include <assert.h>
#include <stdio.h>

static char *fixture(const char *path) {
    FILE *file = fopen(path, "rb");
    assert(file != NULL && fseek(file, 0, SEEK_END) == 0);
    long length = ftell(file);
    assert(length > 0 && length < 1048576);
    rewind(file);
    char *value = malloc((size_t)length + 1u);
    assert(value != NULL && fread(value, 1u, (size_t)length, file) == (size_t)length);
    value[length] = '\0';
    assert(fclose(file) == 0);
    return value;
}

static SSL_CTX *context(const char *key, const char *certificate, const char *authority,
    int minimum, int maximum) {
    char *error = NULL;
    SSL_CTX *result = tsonic_node_tls_context_create(key, certificate, authority, 1,
        NULL, 0u, 0, "", minimum, maximum, &error);
    assert(result != NULL && error == NULL);
    return result;
}

static int handshake(SSL_CTX *server_context, SSL_CTX *client_context, int verify, int require_client) {
    SSL *server = SSL_new(server_context);
    SSL *client = SSL_new(client_context);
    assert(server != NULL && client != NULL);
    BIO *server_bio = NULL;
    BIO *client_bio = NULL;
    assert(BIO_new_bio_pair(&server_bio, 0, &client_bio, 0) == 1);
    SSL_set_bio(server, server_bio, server_bio);
    SSL_set_bio(client, client_bio, client_bio);
    SSL_set_accept_state(server);
    SSL_set_connect_state(client);
    SSL_set_verify(server, require_client ? SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT : SSL_VERIFY_NONE, NULL);
    SSL_set_verify(client, verify ? SSL_VERIFY_PEER : SSL_VERIFY_NONE, NULL);
    assert(SSL_set1_host(client, "localhost") == 1);
    int complete = 0;
    for (int turn = 0; turn < 1000; turn++) {
        int client_status = SSL_do_handshake(client);
        int client_error = SSL_get_error(client, client_status);
        int server_status = SSL_do_handshake(server);
        int server_error = SSL_get_error(server, server_status);
        if (client_status == 1 && server_status == 1) { complete = 1; break; }
        if ((client_status != 1 && client_error != SSL_ERROR_WANT_READ && client_error != SSL_ERROR_WANT_WRITE) ||
            (server_status != 1 && server_error != SSL_ERROR_WANT_READ && server_error != SSL_ERROR_WANT_WRITE)) break;
    }
    SSL_free(client);
    SSL_free(server);
    ERR_clear_error();
    return complete;
}

int main(void) {
    char *certificate = fixture("tests/fixtures/localhost-cert.pem");
    char *key = fixture("tests/fixtures/localhost-key.pem");
    SSL_CTX *server = context(key, certificate, certificate, 3, 4);
    SSL_CTX *client = context(key, certificate, certificate, 3, 4);
    assert(handshake(server, client, 1, 1));
    assert(handshake(server, client, 1, 1));
    SSL_CTX *anonymous = context(NULL, NULL, certificate, 3, 4);
    assert(!handshake(server, anonymous, 1, 1));
    SSL_CTX *untrusted = context(NULL, NULL, "", 3, 4);
    assert(!handshake(server, untrusted, 1, 0));
    assert(handshake(server, untrusted, 0, 0));
    SSL_CTX *older = context(key, certificate, certificate, 3, 3);
    SSL_CTX *newer = context(NULL, NULL, certificate, 4, 4);
    assert(!handshake(older, newer, 0, 0));
    char *error = NULL;
    assert(tsonic_node_tls_context_create(NULL, NULL, "", 1, NULL, 0u, 0, "", 4, 3, &error) == NULL);
    assert(error != NULL); free(error); error = NULL;
    BIO *key_input = BIO_new_mem_buf(key, -1);
    EVP_PKEY *private_key = PEM_read_bio_PrivateKey(key_input, NULL, NULL, NULL);
    BIO_free(key_input);
    assert(private_key != NULL);
    BIO *encrypted = BIO_new(BIO_s_mem());
    const char *password = "fixture-password";
    assert(PEM_write_bio_PrivateKey(encrypted, private_key, EVP_aes_256_cbc(),
        (unsigned char *)password, (int)strlen(password), NULL, NULL) == 1);
    char *encrypted_bytes = NULL;
    long encrypted_length = BIO_get_mem_data(encrypted, &encrypted_bytes);
    char *encrypted_key = malloc((size_t)encrypted_length + 1u);
    assert(encrypted_key != NULL);
    memcpy(encrypted_key, encrypted_bytes, (size_t)encrypted_length);
    encrypted_key[encrypted_length] = '\0';
    SSL_CTX *encrypted_client = tsonic_node_tls_context_create(encrypted_key, certificate, certificate, 1,
        NULL, 0u, 0, password, 3, 4, &error);
    assert(encrypted_client != NULL && error == NULL && handshake(server, encrypted_client, 1, 1));
    assert(tsonic_node_tls_context_create(encrypted_key, certificate, certificate, 1,
        NULL, 0u, 0, "wrong", 3, 4, &error) == NULL);
    assert(error != NULL); free(error); error = NULL;
    BIO *certificate_input = BIO_new_mem_buf(certificate, -1);
    X509 *identity = PEM_read_bio_X509(certificate_input, NULL, NULL, NULL);
    BIO_free(certificate_input);
    assert(identity != NULL);
    PKCS12 *bundle = PKCS12_create(password, "client", private_key, identity, NULL, 0, 0, 0, 0, 0);
    assert(bundle != NULL);
    unsigned char *encoded = NULL;
    int encoded_length = i2d_PKCS12(bundle, &encoded);
    assert(encoded_length > 0);
    SSL_CTX *pfx_client = tsonic_node_tls_context_create(NULL, NULL, certificate, 1,
        encoded, (size_t)encoded_length, 1, password, 3, 4, &error);
    assert(pfx_client != NULL && error == NULL && handshake(server, pfx_client, 1, 1));
    assert(tsonic_node_tls_context_create(NULL, NULL, certificate, 1,
        encoded, (size_t)encoded_length, 1, "wrong", 3, 4, &error) == NULL);
    assert(error != NULL); free(error); error = NULL;
    assert(tsonic_node_tls_context_create(NULL, NULL, certificate, 1,
        encoded, 0u, 1, password, 3, 4, &error) == NULL);
    assert(error != NULL); free(error); error = NULL;
    SSL_CTX *projected = SSL_CTX_new(TLS_method());
    assert(projected != NULL && tsonic_node_tls_context_apply(pfx_client, projected, &error));
    assert(error == NULL);
    tsonic_node_tls_context_free(pfx_client);
    assert(handshake(server, projected, 1, 1));
    SSL_CTX_free(projected);
    SSL_CTX_free(encrypted_client);
    SSL_CTX_free(newer);
    SSL_CTX_free(older);
    SSL_CTX_free(untrusted);
    SSL_CTX_free(anonymous);
    SSL_CTX_free(client);
    SSL_CTX_free(server);
    OPENSSL_free(encoded);
    PKCS12_free(bundle);
    X509_free(identity);
    EVP_PKEY_free(private_key);
    BIO_free(encrypted);
    free(encrypted_key);
    free(key);
    free(certificate);
    puts("TLS identity, mTLS, protocol, trust, context ownership and projection contracts passed");
    return 0;
}
