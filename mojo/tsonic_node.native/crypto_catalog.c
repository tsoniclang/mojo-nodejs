#include <openssl/ec.h>
#include <openssl/evp.h>
#include <openssl/objects.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char **values;
    size_t count;
    size_t capacity;
    int error;
} CryptoNames;

void tsonic_node_crypto_names_free(void *pointer) {
    CryptoNames *names = pointer;
    if (!names) return;
    for (size_t index = 0; index < names->count; ++index) free(names->values[index]);
    free(names->values);
    free(names);
}

static void append_name(const char *name, void *pointer) {
    CryptoNames *names = pointer;
    if (names->error) return;
    if (!name) { names->error = EINVAL; return; }
    if (names->count == names->capacity) {
        if (names->capacity > SIZE_MAX / 2 / sizeof(char *)) { names->error = EOVERFLOW; return; }
        size_t capacity = names->capacity ? names->capacity * 2 : 16;
        char **values = realloc(names->values, capacity * sizeof(char *));
        if (!values) { names->error = ENOMEM; return; }
        names->values = values;
        names->capacity = capacity;
    }
    size_t size = strlen(name) + 1;
    char *value = malloc(size);
    if (!value) { names->error = ENOMEM; return; }
    memcpy(value, name, size);
    names->values[names->count++] = value;
}

static void cipher_names(EVP_CIPHER *cipher, void *context) {
    if (EVP_CIPHER_names_do_all(cipher, append_name, context) != 1)
        ((CryptoNames *)context)->error = EINVAL;
}

static void digest_names(EVP_MD *digest, void *context) {
    if (EVP_MD_names_do_all(digest, append_name, context) != 1)
        ((CryptoNames *)context)->error = EINVAL;
}

static int compare_names(const void *left, const void *right) {
    return strcmp(*(char *const *)left, *(char *const *)right);
}

void *tsonic_node_crypto_names(int kind) {
    CryptoNames *names = calloc(1, sizeof(*names));
    if (!names) { errno = ENOMEM; return NULL; }
    if (kind == 0) EVP_CIPHER_do_all_provided(NULL, cipher_names, names);
    else if (kind == 1) EVP_MD_do_all_provided(NULL, digest_names, names);
    else if (kind == 2) {
        size_t count = EC_get_builtin_curves(NULL, 0);
        if (count > SIZE_MAX / sizeof(EC_builtin_curve)) names->error = EOVERFLOW;
        else if (count != 0) {
            EC_builtin_curve *curves = malloc(count * sizeof(*curves));
            if (!curves) names->error = ENOMEM;
            else {
                size_t actual = EC_get_builtin_curves(curves, count);
                if (actual != count) names->error = EINVAL;
                else for (size_t index = 0; index < count; ++index)
                    append_name(OBJ_nid2sn(curves[index].nid), names);
                free(curves);
            }
        }
    } else names->error = EINVAL;
    if (names->error) {
        int error = names->error;
        tsonic_node_crypto_names_free(names);
        errno = error;
        return NULL;
    }
    if (names->count > 1) qsort(names->values, names->count, sizeof(char *), compare_names);
    size_t unique = 0;
    for (size_t index = 0; index < names->count; ++index) {
        if (unique && strcmp(names->values[unique - 1], names->values[index]) == 0)
            free(names->values[index]);
        else names->values[unique++] = names->values[index];
    }
    names->count = unique;
    return names;
}

size_t tsonic_node_crypto_names_size(const void *pointer) {
    return ((const CryptoNames *)pointer)->count;
}

const char *tsonic_node_crypto_name_at(const void *pointer, size_t index) {
    const CryptoNames *names = pointer;
    if (index >= names->count) return NULL;
    return names->values[index];
}
