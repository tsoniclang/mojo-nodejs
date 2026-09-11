#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <openssl/pkcs12.h>

static int apply_pfx(SSL_CTX *context, const unsigned char *bytes, size_t length,
    const char *password, char **error) {
    if (bytes == NULL || length == 0u || length > LONG_MAX) {
        tsonic_tls_set_error(error, "TLS PFX data has an invalid length");
        return 0;
    }
    const unsigned char *cursor = bytes;
    PKCS12 *bundle = d2i_PKCS12(NULL, &cursor, (long)length);
    EVP_PKEY *key = NULL;
    X509 *certificate = NULL;
    STACK_OF(X509) *chain = NULL;
    int result = bundle != NULL && cursor == bytes + length &&
        PKCS12_parse(bundle, password, &key, &certificate, &chain) == 1 &&
        key != NULL && certificate != NULL &&
        SSL_CTX_use_certificate(context, certificate) == 1 &&
        SSL_CTX_use_PrivateKey(context, key) == 1 &&
        SSL_CTX_check_private_key(context) == 1;
    if (result) {
        result = SSL_CTX_clear_chain_certs(context) == 1;
        for (int index = 0; result && chain != NULL && index < sk_X509_num(chain); index++) {
            result = SSL_CTX_add1_chain_cert(context, sk_X509_value(chain, index)) == 1;
        }
    }
    if (!result) tsonic_tls_set_ssl_error(error, "Unable to load TLS PFX identity");
    PKCS12_free(bundle);
    EVP_PKEY_free(key);
    X509_free(certificate);
    sk_X509_pop_free(chain, X509_free);
    return result;
}

void *tsonic_node_tls_context_create(const char *key_pem, const char *certificate_pem,
    const char *ca_pem, int32_t ca_present, const unsigned char *pfx, size_t pfx_length,
    int32_t pfx_present, const char *passphrase, int32_t minimum, int32_t maximum, char **error) {
    if (error == NULL) return NULL;
    *error = NULL;
    ERR_clear_error();
    const int versions[] = { 0, TLS1_VERSION, TLS1_1_VERSION, TLS1_2_VERSION, TLS1_3_VERSION };
    if (minimum < 0 || minimum > 4 || maximum < 0 || maximum > 4) {
        tsonic_tls_set_error(error, "Unsupported TLS protocol version");
        return NULL;
    }
    int selected_minimum = versions[minimum == 0 ? 3 : minimum];
    int selected_maximum = versions[maximum == 0 ? 4 : maximum];
    if (selected_minimum > selected_maximum) {
        tsonic_tls_set_error(error, "Minimum TLS version exceeds maximum TLS version");
        return NULL;
    }
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    if (context == NULL || SSL_CTX_set_min_proto_version(context, selected_minimum) != 1 ||
        SSL_CTX_set_max_proto_version(context, selected_maximum) != 1) {
        tsonic_tls_set_ssl_error(error, "Unable to initialize TLS protocol limits");
        SSL_CTX_free(context);
        return NULL;
    }
    int complete = ca_present ? tsonic_tls_apply_ca_text(context, ca_pem, error) :
        SSL_CTX_set_default_verify_paths(context) == 1;
    if (complete && (key_pem != NULL || certificate_pem != NULL)) {
        complete = tsonic_tls_apply_certificate(context, certificate_pem, key_pem, passphrase, error);
    }
    if (complete && pfx_present) complete = apply_pfx(context, pfx, pfx_length, passphrase, error);
    if (!complete) {
        if (*error == NULL) tsonic_tls_set_ssl_error(error, "Unable to configure TLS context");
        SSL_CTX_free(context);
        return NULL;
    }
    SSL_CTX_set_alpn_select_cb(context, tsonic_tls_select_alpn, NULL);
    return context;
}

int tsonic_node_tls_context_retain(void *context) {
    return context != NULL && SSL_CTX_up_ref(context) == 1;
}

void tsonic_node_tls_context_free(void *context) {
    SSL_CTX_free(context);
}

int tsonic_node_tls_context_apply(void *source_value, void *destination_value, char **error) {
    SSL_CTX *source = source_value;
    SSL_CTX *destination = destination_value;
    if (error == NULL || source == NULL || destination == NULL) return 0;
    *error = NULL;
    ERR_clear_error();
    X509_STORE *store = SSL_CTX_get_cert_store(source);
    if (X509_STORE_up_ref(store) != 1) {
        tsonic_tls_set_ssl_error(error, "Unable to retain TLS trust store");
        return 0;
    }
    SSL_CTX_set_cert_store(destination, store);
    int complete = SSL_CTX_set_min_proto_version(destination, SSL_CTX_get_min_proto_version(source)) == 1 &&
        SSL_CTX_set_max_proto_version(destination, SSL_CTX_get_max_proto_version(source)) == 1;
    X509 *certificate = SSL_CTX_get0_certificate(source);
    EVP_PKEY *key = SSL_CTX_get0_privatekey(source);
    if (complete && certificate != NULL) complete = SSL_CTX_use_certificate(destination, certificate) == 1;
    if (complete && key != NULL) complete = SSL_CTX_use_PrivateKey(destination, key) == 1;
    STACK_OF(X509) *chain = NULL;
    SSL_CTX_get0_chain_certs(source, &chain);
    if (complete) complete = SSL_CTX_clear_chain_certs(destination) == 1;
    for (int index = 0; complete && chain != NULL && index < sk_X509_num(chain); index++) {
        complete = SSL_CTX_add1_chain_cert(destination, sk_X509_value(chain, index)) == 1;
    }
    if (!complete) tsonic_tls_set_ssl_error(error, "Unable to apply the selected TLS context");
    return complete;
}
