#include "../../mojo/tsonic_node.native/tls/model.h"
#include <assert.h>
#include <openssl/x509v3.h>

static void extension(X509 *certificate, X509 *issuer, int identifier, const char *value) {
    X509V3_CTX context;
    X509V3_set_ctx(&context, issuer, certificate, NULL, NULL, 0);
    X509_EXTENSION *entry = X509V3_EXT_conf_nid(NULL, &context, identifier, value);
    assert(entry != NULL);
    assert(X509_add_ext(certificate, entry, -1) == 1);
    X509_EXTENSION_free(entry);
}

static X509 *certificate(EVP_PKEY *key, X509 *issuer, EVP_PKEY *issuer_key,
    const char *name, long serial, int authority) {
    X509 *result = X509_new();
    assert(result != NULL);
    assert(X509_set_version(result, 2) == 1);
    assert(ASN1_INTEGER_set(X509_get_serialNumber(result), serial) == 1);
    assert(X509_gmtime_adj(X509_getm_notBefore(result), -60) != NULL);
    assert(X509_gmtime_adj(X509_getm_notAfter(result), 3600) != NULL);
    assert(X509_set_pubkey(result, key) == 1);
    X509_NAME *subject = X509_get_subject_name(result);
    assert(X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_ASC,
        (const unsigned char *)name, -1, -1, 0) == 1);
    assert(X509_set_issuer_name(result, issuer == NULL ? subject : X509_get_subject_name(issuer)) == 1);
    extension(result, issuer == NULL ? result : issuer, NID_basic_constraints,
        authority ? "critical,CA:TRUE" : "critical,CA:FALSE");
    extension(result, issuer == NULL ? result : issuer, NID_key_usage,
        authority ? "critical,keyCertSign,cRLSign" : "critical,digitalSignature");
    if (!authority) {
        extension(result, issuer, NID_ext_key_usage, "serverAuth");
        extension(result, issuer, NID_subject_alt_name, "DNS:localhost");
    }
    assert(X509_sign(result, issuer_key == NULL ? key : issuer_key, EVP_sha256()) > 0);
    return result;
}

static char *bio_text(BIO *bio) {
    BUF_MEM *buffer = NULL;
    BIO_get_mem_ptr(bio, &buffer);
    assert(buffer != NULL);
    char *result = malloc(buffer->length + 1);
    assert(result != NULL);
    memcpy(result, buffer->data, buffer->length);
    result[buffer->length] = '\0';
    BIO_free(bio);
    return result;
}

static char *pem_certificate(X509 *value) {
    BIO *bio = BIO_new(BIO_s_mem());
    assert(bio != NULL);
    assert(PEM_write_bio_X509(bio, value) == 1);
    return bio_text(bio);
}

static char *pem_key(EVP_PKEY *key, int encrypted) {
    BIO *bio = BIO_new(BIO_s_mem());
    assert(bio != NULL);
    const unsigned char password[] = "test-only";
    assert(PEM_write_bio_PrivateKey(bio, key, encrypted ? EVP_aes_256_cbc() : NULL,
        encrypted ? password : NULL, encrypted ? sizeof(password) - 1 : 0, NULL, NULL) == 1);
    return bio_text(bio);
}

static char *concat(const char *first, const char *second) {
    size_t first_length = strlen(first);
    size_t second_length = strlen(second);
    char *result = malloc(first_length + second_length + 1);
    assert(result != NULL);
    memcpy(result, first, first_length);
    memcpy(result + first_length, second, second_length + 1);
    return result;
}

static int handshake(SSL_CTX *server_context, SSL_CTX *client_context) {
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
    assert(SSL_set1_host(client, "localhost") == 1);
    int succeeded = 0;
    for (int attempt = 0; attempt < 128; ++attempt) {
        ERR_clear_error();
        int client_result = SSL_do_handshake(client);
        int client_error = SSL_get_error(client, client_result);
        if (client_result != 1 && client_error != SSL_ERROR_WANT_READ &&
            client_error != SSL_ERROR_WANT_WRITE) break;
        ERR_clear_error();
        int server_result = SSL_do_handshake(server);
        int server_error = SSL_get_error(server, server_result);
        if (server_result != 1 && server_error != SSL_ERROR_WANT_READ &&
            server_error != SSL_ERROR_WANT_WRITE) break;
        if (client_result == 1 && server_result == 1) {
            succeeded = SSL_get_verify_result(client) == X509_V_OK;
            break;
        }
    }
    SSL_free(server);
    SSL_free(client);
    ERR_clear_error();
    return succeeded;
}

int main(void) {
    EVP_PKEY *root_key = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "prime256v1");
    EVP_PKEY *intermediate_key = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "prime256v1");
    EVP_PKEY *leaf_key = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "prime256v1");
    assert(root_key != NULL && intermediate_key != NULL && leaf_key != NULL);
    X509 *root = certificate(root_key, NULL, NULL, "Test root", 1, 1);
    X509 *intermediate = certificate(intermediate_key, root, root_key, "Test intermediate", 2, 1);
    X509 *leaf = certificate(leaf_key, intermediate, intermediate_key, "localhost", 3, 0);
    char *root_pem = pem_certificate(root);
    char *intermediate_pem = pem_certificate(intermediate);
    char *leaf_pem = pem_certificate(leaf);
    char *key_pem = pem_key(leaf_key, 0);
    char *wrong_key = pem_key(root_key, 0);
    char *encrypted_key = pem_key(leaf_key, 1);
    char *chain = concat(leaf_pem, intermediate_pem);
    char *duplicate_root = concat(root_pem, root_pem);
    char *malformed_chain = concat(leaf_pem,
        "-----BEGIN CERTIFICATE-----\ninvalid*base64\n-----END CERTIFICATE-----\n");
    SSL_CTX *client = SSL_CTX_new(TLS_client_method());
    SSL_CTX *server = SSL_CTX_new(TLS_server_method());
    assert(client != NULL && server != NULL);
    SSL_CTX_set_verify(client, SSL_VERIFY_PEER, NULL);
    char *error = NULL;
    assert(tsonic_tls_apply_ca_text(client, duplicate_root, &error));
    assert(error == NULL);
    assert(tsonic_tls_apply_certificate(server, chain, key_pem, NULL, &error));
    assert(error == NULL);
    STACK_OF(X509) *retained = NULL;
    assert(SSL_CTX_get0_chain_certs(server, &retained) == 1);
    assert(retained != NULL && sk_X509_num(retained) == 1);
    assert(handshake(server, client));
    assert(tsonic_tls_apply_certificate(server, leaf_pem, key_pem, NULL, &error));
    assert(!handshake(server, client));
    assert(!tsonic_tls_apply_certificate(server, malformed_chain, key_pem, NULL, &error));
    assert(error != NULL);
    free(error);
    error = NULL;
    assert(!tsonic_tls_apply_certificate(server, chain, wrong_key, NULL, &error));
    assert(error != NULL);
    free(error);
    error = NULL;
    assert(!tsonic_tls_apply_certificate(server, chain, encrypted_key, NULL, &error));
    assert(error != NULL);
    free(error);
    SSL_CTX_free(server);
    SSL_CTX_free(client);
    free(malformed_chain);
    free(duplicate_root);
    free(chain);
    free(encrypted_key);
    free(wrong_key);
    free(key_pem);
    free(leaf_pem);
    free(intermediate_pem);
    free(root_pem);
    X509_free(leaf);
    X509_free(intermediate);
    X509_free(root);
    EVP_PKEY_free(leaf_key);
    EVP_PKEY_free(intermediate_key);
    EVP_PKEY_free(root_key);
    return 0;
}
