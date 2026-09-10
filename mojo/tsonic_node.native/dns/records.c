#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int same_dns_name(const char *left, const char *right) {
    if (left == NULL || right == NULL) return 0;
    size_t left_size = strlen(left);
    size_t right_size = strlen(right);
    if (left_size != 0 && left[left_size - 1] == '.') left_size--;
    if (right_size != 0 && right[right_size - 1] == '.') right_size--;
    if (left_size != right_size) return 0;
    for (size_t index = 0; index < left_size; index++) {
        unsigned char first = (unsigned char)left[index];
        unsigned char second = (unsigned char)right[index];
        if (first >= 'A' && first <= 'Z') first += 'a' - 'A';
        if (second >= 'A' && second <= 'Z') second += 'a' - 'A';
        if (first != second) return 0;
    }
    return 1;
}

void tsonic_dns_dns_failure(TsonicDnsRequest *request, ares_status_t status) {
    const char *code;
    char unknown[32];
    switch (status) {
        case ARES_ENODATA: code = "ENODATA"; break;
        case ARES_EFORMERR: code = "EFORMERR"; break;
        case ARES_ESERVFAIL: code = "ESERVFAIL"; break;
        case ARES_ENOTFOUND: code = "ENOTFOUND"; break;
        case ARES_ENOTIMP: code = "ENOTIMP"; break;
        case ARES_EREFUSED: code = "EREFUSED"; break;
        case ARES_EBADQUERY: code = "EBADQUERY"; break;
        case ARES_EBADNAME: code = "EBADNAME"; break;
        case ARES_EBADFAMILY: code = "EBADFAMILY"; break;
        case ARES_EBADRESP: code = "EBADRESP"; break;
        case ARES_ECONNREFUSED: code = "ECONNREFUSED"; break;
        case ARES_ETIMEOUT: code = "ETIMEOUT"; break;
        case ARES_EOF: code = "EOF"; break;
        case ARES_EFILE: code = "EFILE"; break;
        case ARES_ENOMEM: code = "ENOMEM"; break;
        case ARES_EDESTRUCTION: code = "EDESTRUCTION"; break;
        case ARES_EBADSTR: code = "EBADSTR"; break;
        case ARES_EBADFLAGS: code = "EBADFLAGS"; break;
        case ARES_ENONAME: code = "ENONAME"; break;
        case ARES_EBADHINTS: code = "EBADHINTS"; break;
        case ARES_ENOTINITIALIZED: code = "ENOTINITIALIZED"; break;
        case ARES_ECANCELLED: code = "ECANCELLED"; break;
        case ARES_ESERVICE: code = "ESERVICE"; break;
        case ARES_ENOSERVER: code = "ENOSERVER"; break;
        default:
            snprintf(unknown, sizeof(unknown), "EARES%d", (int)status);
            code = unknown;
            break;
    }
    tsonic_dns_request_fail(request, code, ares_strerror(status));
}

void tsonic_dns_collect_records(TsonicDnsRequest *request, const ares_dns_record_t *records) {
    const char *name = NULL;
    if (records == NULL || ares_dns_record_query_cnt(records) != 1 ||
        ares_dns_record_query_get(records, 0, &name, NULL, NULL) != ARES_SUCCESS) {
        tsonic_dns_dns_failure(request, ARES_EBADRESP);
        return;
    }
    size_t count = ares_dns_record_rr_cnt(records, ARES_SECTION_ANSWER);
    if (count > TSONIC_DNS_RESULT_LIMIT) {
        tsonic_dns_request_fail(request, "ENOMEM", "DNS response exceeds the closed record limit");
        return;
    }
    const char **visited = calloc(count + 1, sizeof(*visited));
    if (visited == NULL) { tsonic_dns_dns_failure(request, ARES_ENOMEM); return; }
    for (size_t step = 0; step <= count && !request->failed; step++) {
        for (size_t index = 0; index < step; index++) {
            if (same_dns_name(name, visited[index])) tsonic_dns_dns_failure(request, ARES_EBADRESP);
        }
        if (request->failed) break;
        visited[step] = name;
        const char *alias = NULL;
        for (size_t index = 0; index < count && !request->failed; index++) {
            const ares_dns_rr_t *record = ares_dns_record_rr_get_const(records, ARES_SECTION_ANSWER, index);
            if (ares_dns_rr_get_class(record) != ARES_CLASS_IN || !same_dns_name(name, ares_dns_rr_get_name(record))) continue;
            ares_dns_rec_type_t type = ares_dns_rr_get_type(record);
            char address[INET6_ADDRSTRLEN];
            const char *text = NULL;
            if (type == ARES_REC_TYPE_CNAME) {
                const char *next = ares_dns_rr_get_str(record, ARES_RR_CNAME_CNAME);
                if (next == NULL || (alias != NULL && !same_dns_name(alias, next))) tsonic_dns_dns_failure(request, ARES_EBADRESP);
                else alias = next;
            } else if (request->kind == 4 && type == ARES_REC_TYPE_A) {
                const struct in_addr *bytes = ares_dns_rr_get_addr(record, ARES_RR_A_ADDR);
                if (bytes != NULL) text = inet_ntop(AF_INET, bytes, address, sizeof(address));
                if (text == NULL) tsonic_dns_dns_failure(request, ARES_EBADRESP);
            } else if (request->kind == 6 && type == ARES_REC_TYPE_AAAA) {
                const struct ares_in6_addr *bytes = ares_dns_rr_get_addr6(record, ARES_RR_AAAA_ADDR);
                if (bytes != NULL) text = inet_ntop(AF_INET6, bytes, address, sizeof(address));
                if (text == NULL) tsonic_dns_dns_failure(request, ARES_EBADRESP);
            } else if (request->kind == -1 && type == ARES_REC_TYPE_PTR) {
                text = ares_dns_rr_get_str(record, ARES_RR_PTR_DNAME);
                if (text == NULL) tsonic_dns_dns_failure(request, ARES_EBADRESP);
            }
            if (text != NULL) tsonic_dns_result_append(request, text);
        }
        if (request->count != 0 || request->failed) break;
        if (alias == NULL) { tsonic_dns_dns_failure(request, ARES_ENODATA); break; }
        name = alias;
    }
    free(visited);
    if (request->count == 0 && !request->failed) tsonic_dns_dns_failure(request, ARES_EBADRESP);
}
