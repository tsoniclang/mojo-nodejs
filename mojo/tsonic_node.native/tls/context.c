#define _POSIX_C_SOURCE 200809L
#include "model.h"

char *tsonic_tls_copy_text(const char *value) {
    if (value == NULL) return NULL;
    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1u);
    if (copy != NULL) memcpy(copy, value, length + 1u);
    return copy;
}

void tsonic_tls_set_error(char **error, const char *message) {
    if (error != NULL) *error = tsonic_tls_copy_text(message);
}

void tsonic_tls_set_ssl_error(char **error, const char *fallback) {
    unsigned long code = ERR_get_error();
    if (code == 0u) {
        tsonic_tls_set_error(error, fallback);
        return;
    }
    char buffer[256];
    ERR_error_string_n(code, buffer, sizeof(buffer));
    tsonic_tls_set_error(error, buffer);
}

int tsonic_tls_allow_unverified(int valid, X509_STORE_CTX *store) {
    (void)valid;
    (void)store;
    return 1;
}

int tsonic_tls_apply_ca_text(SSL_CTX *context, const char *pem, char **error) {
    if (pem == NULL || pem[0] == '\0') return 1;
    BIO *bio = BIO_new_mem_buf(pem, -1);
    if (bio == NULL) {
        tsonic_tls_set_ssl_error(error, "Unable to read TLS certificate authority data");
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
        tsonic_tls_set_error(error, "TLS certificate authority data contains no certificate");
        return 0;
    }
    return 1;
}

int tsonic_tls_apply_certificate(
    SSL_CTX *context,
    const char *certificate_pem,
    const char *key_pem,
    char **error
) {
    if (certificate_pem == NULL || key_pem == NULL ||
        certificate_pem[0] == '\0' || key_pem[0] == '\0') {
        tsonic_tls_set_error(error, "TLS server requires non-empty cert and key values");
        return 0;
    }
    BIO *certificate_bio = BIO_new_mem_buf(certificate_pem, -1);
    BIO *key_bio = BIO_new_mem_buf(key_pem, -1);
    if (certificate_bio == NULL || key_bio == NULL) {
        BIO_free(certificate_bio);
        BIO_free(key_bio);
        tsonic_tls_set_ssl_error(error, "Unable to read TLS server identity");
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
        tsonic_tls_set_ssl_error(error, "TLS server certificate and key do not form a valid identity");
        return 0;
    }
    X509_free(certificate);
    EVP_PKEY_free(key);
    return 1;
}
