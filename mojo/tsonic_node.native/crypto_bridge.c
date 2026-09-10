#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/params.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct {
    EVP_MD *algorithm;
    EVP_MD_CTX *digest;
    EVP_MAC_CTX *mac;
    size_t size;
    int finalized;
} TsonicDigest;

void tsonic_node_digest_free(TsonicDigest *state) {
    if (state == NULL) return;
    EVP_MD_CTX_free(state->digest);
    EVP_MD_free(state->algorithm);
    EVP_MAC_CTX_free(state->mac);
    free(state);
}

TsonicDigest *tsonic_node_digest_copy(const TsonicDigest *source) {
    if (source->finalized || source->mac != NULL) return NULL;
    TsonicDigest *result = calloc(1, sizeof(*result));
    if (result == NULL) return NULL;
    result->size = source->size;
    if (EVP_MD_up_ref(source->algorithm) != 1) goto failure;
    result->algorithm = source->algorithm;
    result->digest = EVP_MD_CTX_new();
    if (result->digest == NULL || EVP_MD_CTX_copy_ex(result->digest, source->digest) != 1) goto failure;
    return result;
failure:
    tsonic_node_digest_free(result);
    return NULL;
}

int tsonic_node_timing_safe_equal(const unsigned char *left,
                                 const unsigned char *right, size_t length) {
    return CRYPTO_memcmp(left, right, length) == 0;
}

TsonicDigest *tsonic_node_digest_create(const char *algorithm,
                                       const unsigned char *key,
                                       size_t key_length, int keyed) {
    TsonicDigest *state = calloc(1, sizeof(*state));
    if (state == NULL) return NULL;
    if (keyed) {
        EVP_MAC *implementation = EVP_MAC_fetch(NULL, "HMAC", NULL);
        if (implementation == NULL) goto failure;
        state->mac = EVP_MAC_CTX_new(implementation);
        EVP_MAC_free(implementation);
        if (state->mac == NULL) goto failure;
        OSSL_PARAM parameters[] = {
            OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST,
                                             (char *)algorithm, 0),
            OSSL_PARAM_construct_end()
        };
        const unsigned char empty_key = 0;
        if (EVP_MAC_init(state->mac, key_length == 0 ? &empty_key : key,
                         key_length, parameters) != 1) goto failure;
        state->size = EVP_MAC_CTX_get_mac_size(state->mac);
    } else {
        state->algorithm = EVP_MD_fetch(NULL, algorithm, NULL);
        if (state->algorithm == NULL) goto failure;
        int size = EVP_MD_get_size(state->algorithm);
        if (size <= 0 || (EVP_MD_get_flags(state->algorithm) & EVP_MD_FLAG_XOF))
            goto failure;
        state->size = (size_t)size;
        state->digest = EVP_MD_CTX_new();
        if (state->digest == NULL ||
            EVP_DigestInit_ex2(state->digest, state->algorithm, NULL) != 1)
            goto failure;
    }
    if (state->size == 0) goto failure;
    return state;
failure:
    tsonic_node_digest_free(state);
    return NULL;
}

size_t tsonic_node_digest_size(const TsonicDigest *state) {
    return state->size;
}

int tsonic_node_digest_update(TsonicDigest *state, const unsigned char *bytes,
                              size_t length) {
    if (state->finalized) return 0;
    if (length == 0) return 1;
    int success = state->mac != NULL
        ? EVP_MAC_update(state->mac, bytes, length)
        : EVP_DigestUpdate(state->digest, bytes, length);
    if (success != 1) state->finalized = 1;
    return success == 1;
}

int tsonic_node_digest_finish(TsonicDigest *state, unsigned char *bytes,
                              size_t length) {
    if (state->finalized || length != state->size) return 0;
    state->finalized = 1;
    if (state->mac != NULL) {
        size_t written = 0;
        return EVP_MAC_final(state->mac, bytes, &written, length) == 1 &&
               written == length;
    }
    unsigned int written = 0;
    return EVP_DigestFinal_ex(state->digest, bytes, &written) == 1 &&
           written == length;
}

int tsonic_node_random_bytes(unsigned char *bytes, size_t length) {
    return length == 0 || RAND_bytes_ex(NULL, bytes, length, 0) == 1;
}
