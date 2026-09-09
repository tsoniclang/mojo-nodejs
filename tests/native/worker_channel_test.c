#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/worker/model.h"
#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static void pause_tick(void) {
    struct timespec duration = { 0, 1000000 };
    nanosleep(&duration, NULL);
}

static int child(TsonicWorkerChannel *channel) {
    assert(tsonic_node_worker_wait(channel, 10000) == 0);
    uint8_t kind;
    const uint8_t *bytes;
    size_t length;
    assert(tsonic_node_worker_message(channel, &kind, &bytes, &length) == 1);
    assert(kind == 0);
    if (length == 1 && bytes[0] == 255) {
        for (;;) pause();
    }
    assert(tsonic_node_worker_send(channel, 2, bytes, length) == 0);
    tsonic_node_worker_consume(channel);
    assert(tsonic_node_worker_flush(channel, 10000) == 0);
    tsonic_node_worker_free(channel);
    return 0;
}

static void pair_proof(void) {
    TsonicWorkerChannel *first;
    TsonicWorkerChannel *second;
    assert(tsonic_node_worker_pair(&first, &second) == 0);
    size_t length = 2 * 1024 * 1024;
    uint8_t *source = malloc(length);
    assert(source != NULL);
    for (size_t index = 0; index < length; index++) source[index] = (uint8_t)(index * 17);
    assert(tsonic_node_worker_send(first, 2, source, length) == 0);
    int received = 0;
    for (int turn = 0; turn < 10000 && !received; turn++) {
        assert(tsonic_node_worker_progress(first) == 0);
        assert(tsonic_node_worker_progress(second) == 0);
        uint8_t kind;
        const uint8_t *bytes;
        size_t size;
        received = tsonic_node_worker_message(second, &kind, &bytes, &size);
        if (received) {
            assert(kind == 2 && size == length && memcmp(bytes, source, length) == 0);
            tsonic_node_worker_consume(second);
        }
    }
    assert(received);
    assert(!tsonic_node_worker_pending(first));
    assert(tsonic_node_worker_send(first, 2, NULL, TSONIC_WORKER_FRAME_LIMIT) == EMSGSIZE);
    assert(tsonic_node_worker_send(second, 7, NULL, 0) == 0);
    assert(tsonic_node_worker_wait(first, 10000) == 0);
    uint8_t kind;
    const uint8_t *bytes;
    size_t size;
    assert(tsonic_node_worker_message(first, &kind, &bytes, &size) == 1 && kind == 7 && size == 0);
    tsonic_node_worker_consume(first);
    tsonic_node_worker_close(second);
    assert(tsonic_node_worker_send(first, 2, source, 1) == EPIPE);
    tsonic_node_worker_free(first);
    tsonic_node_worker_free(second);
    free(source);
}

static void malformed_proof(void) {
    TsonicWorkerChannel *first;
    TsonicWorkerChannel *second;
    assert(tsonic_node_worker_pair(&first, &second) == 0);
    uint8_t oversized[] = { 255, 255, 255, 127 };
    assert(send(first->descriptor, oversized, sizeof(oversized), MSG_NOSIGNAL) == sizeof(oversized));
    assert(tsonic_node_worker_progress(second) == EMSGSIZE);
    tsonic_node_worker_free(first);
    tsonic_node_worker_free(second);
    assert(tsonic_node_worker_pair(&first, &second) == 0);
    uint8_t partial[] = { 5, 0 };
    assert(send(first->descriptor, partial, sizeof(partial), MSG_NOSIGNAL) == sizeof(partial));
    tsonic_node_worker_close(first);
    assert(tsonic_node_worker_progress(second) == EPROTO);
    tsonic_node_worker_free(first);
    tsonic_node_worker_free(second);
}

static void process_proof(int terminate) {
    int status = 0;
    TsonicWorkerChannel *channel = tsonic_node_worker_spawn("worker-test\0", 12, "", 0, 1, &status);
    assert(channel != NULL && status == 0);
    int identity = tsonic_node_worker_id(channel);
    assert(identity > 0 && identity != getpid());
    uint8_t payload[] = { terminate ? 255 : 42 };
    assert(tsonic_node_worker_send(channel, 0, payload, sizeof(payload)) == 0);
    if (terminate) {
        assert(tsonic_node_worker_terminate(channel) == 0);
    } else {
        assert(tsonic_node_worker_wait(channel, 10000) == 0);
        uint8_t kind;
        const uint8_t *bytes;
        size_t length;
        assert(tsonic_node_worker_message(channel, &kind, &bytes, &length) == 1);
        assert(kind == 2 && length == 1 && bytes[0] == 42);
        tsonic_node_worker_consume(channel);
    }
    int code = -1;
    int exited = 0;
    for (int turn = 0; turn < 10000 && !exited; turn++) {
        exited = tsonic_node_worker_exit(channel, &code);
        assert(exited >= 0);
        if (!exited) pause_tick();
    }
    assert(exited == 1 && code == (terminate ? 1 : 0));
    assert(tsonic_node_worker_exit(channel, &code) == 1);
    assert(waitpid(identity, NULL, WNOHANG) == -1 && errno == ECHILD);
    tsonic_node_worker_free(channel);
}

int main(void) {
    int status = 0;
    TsonicWorkerChannel *adopted = tsonic_node_worker_adopt(&status);
    assert(status == 0);
    if (adopted != NULL) return child(adopted);
    pair_proof();
    malformed_proof();
    process_proof(0);
    process_proof(1);
    assert(tsonic_node_worker_spawn("unterminated", 12, "", 0, 1, &status) == NULL && status == EINVAL);
    return 0;
}
