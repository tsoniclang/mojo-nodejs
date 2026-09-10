#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/dns/api.h"
#include <ares.h>
#include <arpa/inet.h>
#include <assert.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

static void add_text(ares_dns_record_t *response, const char *owner, ares_dns_rec_type_t type, ares_dns_rr_key_t key, const char *value) {
    ares_dns_rr_t *record = NULL;
    assert(ares_dns_record_rr_add(&record, response, ARES_SECTION_ANSWER, owner, type, ARES_CLASS_IN, 60) == ARES_SUCCESS);
    assert(ares_dns_rr_set_str(record, key, value) == ARES_SUCCESS);
}

static void add_address(ares_dns_record_t *response, const char *owner, int family, const char *value) {
    ares_dns_rr_t *record = NULL;
    assert(ares_dns_record_rr_add(&record, response, ARES_SECTION_ANSWER, owner,
        family == 4 ? ARES_REC_TYPE_A : ARES_REC_TYPE_AAAA, ARES_CLASS_IN, 60) == ARES_SUCCESS);
    if (family == 4) {
        struct in_addr address;
        assert(inet_pton(AF_INET, value, &address) == 1);
        assert(ares_dns_rr_set_addr(record, ARES_RR_A_ADDR, &address) == ARES_SUCCESS);
    } else {
        struct ares_in6_addr address;
        assert(inet_pton(AF_INET6, value, &address) == 1);
        assert(ares_dns_rr_set_addr6(record, ARES_RR_AAAA_ADDR, &address) == ARES_SUCCESS);
    }
}

static void reply(int descriptor) {
    struct pollfd pending = { descriptor, POLLIN, 0 };
    assert(poll(&pending, 1, 10000) == 1);
    uint8_t buffer[65536];
    struct sockaddr_storage peer;
    socklen_t peer_size = sizeof(peer);
    ssize_t received = recvfrom(descriptor, buffer, sizeof(buffer), 0, (struct sockaddr *)&peer, &peer_size);
    assert(received > 0);
    ares_dns_record_t *question = NULL;
    assert(ares_dns_parse(buffer, (size_t)received, 0, &question) == ARES_SUCCESS);
    const char *name = NULL;
    ares_dns_rec_type_t type;
    ares_dns_class_t dns_class;
    assert(ares_dns_record_query_get(question, 0, &name, &type, &dns_class) == ARES_SUCCESS);
    ares_dns_record_t *response = NULL;
    int missing = strcasecmp(name, "missing.example.test") == 0;
    assert(ares_dns_record_create(&response, ares_dns_record_get_id(question), ARES_FLAG_QR | ARES_FLAG_AA | ARES_FLAG_RD,
        ARES_OPCODE_QUERY, missing ? ARES_RCODE_NXDOMAIN : ARES_RCODE_NOERROR) == ARES_SUCCESS);
    assert(ares_dns_record_query_add(response, name, type, dns_class) == ARES_SUCCESS);
    if (!missing) {
        add_address(response, "unrelated.example.test", 4, "192.0.2.99");
        if (strcasecmp(name, "alias.example.test") == 0) {
            add_text(response, name, ARES_REC_TYPE_CNAME, ARES_RR_CNAME_CNAME, "canonical.example.test");
            add_address(response, "canonical.example.test", 4, "192.0.2.42");
        } else if (strcasecmp(name, "cycle.example.test") == 0) {
            add_text(response, name, ARES_REC_TYPE_CNAME, ARES_RR_CNAME_CNAME, "other.example.test");
            add_text(response, "other.example.test", ARES_REC_TYPE_CNAME, ARES_RR_CNAME_CNAME, name);
        } else if (strcasecmp(name, "empty.example.test") != 0) {
            if (type == ARES_REC_TYPE_A) {
                add_address(response, name, 4, "192.0.2.42");
                add_address(response, name, 4, "192.0.2.43");
            } else if (type == ARES_REC_TYPE_AAAA) {
                add_address(response, name, 6, "2001:db8::42");
            } else {
                assert(type == ARES_REC_TYPE_PTR);
                add_text(response, name, ARES_REC_TYPE_PTR, ARES_RR_PTR_DNAME, "first.example.test");
                add_text(response, name, ARES_REC_TYPE_PTR, ARES_RR_PTR_DNAME, "second.example.test");
            }
        }
    }
    unsigned char *wire = NULL;
    size_t size = 0;
    assert(ares_dns_write(response, &wire, &size) == ARES_SUCCESS);
    assert(sendto(descriptor, wire, size, 0, (const struct sockaddr *)&peer, peer_size) == (ssize_t)size);
    ares_free_string(wire);
    ares_dns_record_destroy(response);
    ares_dns_record_destroy(question);
}

static void wait_ready(TsonicDnsRequest *request) {
    assert(request != NULL);
    for (int turn = 0; turn < 10000 && !tsonic_node_dns_request_ready(request); turn++) {
        tsonic_node_dns_lookup_poll();
        struct timespec interval = { 0, 1000000 };
        nanosleep(&interval, NULL);
    }
    assert(tsonic_node_dns_request_ready(request));
}

static TsonicDnsRequest *query(TsonicDnsResolver *resolver, int server, const char *name, int kind) {
    TsonicDnsRequest *request = tsonic_node_dns_query_start(resolver, name, kind);
    assert(request != NULL && !tsonic_node_dns_request_ready(request));
    reply(server);
    wait_ready(request);
    return request;
}

int main(void) {
    int descriptor = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    assert(descriptor >= 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    assert(bind(descriptor, (struct sockaddr *)&address, sizeof(address)) == 0);
    socklen_t size = sizeof(address);
    assert(getsockname(descriptor, (struct sockaddr *)&address, &size) == 0);
    char server[64];
    snprintf(server, sizeof(server), "127.0.0.1:%u", ntohs(address.sin_port));
    int status = 0;
    TsonicDnsResolver *resolver = tsonic_node_dns_resolver_new(server, &status);
    assert(resolver != NULL && status == 0);

    TsonicDnsRequest *records = query(resolver, descriptor, "records.example.test", 4);
    assert(!tsonic_node_dns_request_failed(records));
    assert(tsonic_node_dns_request_count(records) == 2);
    assert(strcmp(tsonic_node_dns_request_value(records, 0), "192.0.2.42") == 0);
    assert(strcmp(tsonic_node_dns_request_value(records, 1), "192.0.2.43") == 0);
    assert(tsonic_node_dns_request_value(records, 2) == NULL);
    tsonic_node_dns_request_free(records);

    records = query(resolver, descriptor, "records.example.test", 6);
    assert(tsonic_node_dns_request_count(records) == 1);
    assert(strcmp(tsonic_node_dns_request_value(records, 0), "2001:db8::42") == 0);
    tsonic_node_dns_request_free(records);
    records = query(resolver, descriptor, "127.0.0.42", -1);
    assert(tsonic_node_dns_request_count(records) == 2);
    assert(strcmp(tsonic_node_dns_request_value(records, 1), "second.example.test") == 0);
    tsonic_node_dns_request_free(records);
    records = query(resolver, descriptor, "alias.example.test", 4);
    assert(tsonic_node_dns_request_count(records) == 1);
    assert(strcmp(tsonic_node_dns_request_value(records, 0), "192.0.2.42") == 0);
    tsonic_node_dns_request_free(records);

    const char *names[] = { "cycle.example.test", "empty.example.test", "missing.example.test" };
    const char *errors[] = { "EBADRESP", "ENODATA", "ENOTFOUND" };
    for (size_t index = 0; index < 3; index++) {
        records = query(resolver, descriptor, names[index], 4);
        assert(tsonic_node_dns_request_failed(records));
        assert(strcmp(tsonic_node_dns_request_code(records), errors[index]) == 0);
        assert(tsonic_node_dns_request_count(records) == 0);
        tsonic_node_dns_request_free(records);
    }

    TsonicDnsRequest *concurrent[16];
    for (size_t index = 0; index < 16; index++) {
        char name[64];
        snprintf(name, sizeof(name), "parallel-%zu.example.test", index);
        concurrent[index] = tsonic_node_dns_query_start(resolver, name, 4);
        assert(concurrent[index] != NULL);
    }
    for (size_t index = 0; index < 16; index++) reply(descriptor);
    for (size_t index = 0; index < 16; index++) {
        wait_ready(concurrent[index]);
        assert(tsonic_node_dns_request_count(concurrent[index]) == 2);
        tsonic_node_dns_request_free(concurrent[index]);
    }
    records = tsonic_node_dns_query_start(resolver, "not an IP", -1);
    assert(records != NULL && tsonic_node_dns_request_ready(records));
    assert(strcmp(tsonic_node_dns_request_code(records), "EINVAL") == 0);
    tsonic_node_dns_request_free(records);
    records = tsonic_node_dns_query_start(resolver, "cancelled.example.test", 4);
    TsonicDnsRequest *discarded = tsonic_node_dns_query_start(resolver, "discarded.example.test", 4);
    assert(discarded != NULL);
    tsonic_node_dns_request_free(discarded);
    tsonic_node_dns_resolver_free(resolver);
    assert(tsonic_node_dns_request_ready(records));
    assert(strcmp(tsonic_node_dns_request_code(records), "EDESTRUCTION") == 0);
    tsonic_node_dns_request_free(records);
    close(descriptor);

    records = tsonic_node_dns_lookup_start("127.0.0.1");
    wait_ready(records);
    assert(tsonic_node_dns_request_family(records) == 4);
    assert(strcmp(tsonic_node_dns_request_value(records, 0), "127.0.0.1") == 0);
    tsonic_node_dns_request_free(records);
    records = tsonic_node_dns_lookup_start("localhost");
    wait_ready(records);
    assert(!tsonic_node_dns_request_failed(records));
    assert(tsonic_node_dns_request_family(records) == 4 || tsonic_node_dns_request_family(records) == 6);
    tsonic_node_dns_request_free(records);
    return 0;
}
