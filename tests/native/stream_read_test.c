#define _POSIX_C_SOURCE 200809L
#include "../../mojo/tsonic_node.native/stream/read.h"
#include <assert.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <uv.h>

static int64_t now_ns(void) {
    struct timespec clock;
    assert(clock_gettime(CLOCK_MONOTONIC, &clock) == 0);
    return (int64_t)clock.tv_sec * 1000000000 + clock.tv_nsec;
}

static void wait_ready(TsonicStreamRead *request) {
    int64_t deadline = now_ns() + 10000000000;
    while (!tsonic_node_stream_read_ready(request)) {
        assert(now_ns() < deadline);
        tsonic_node_stream_read_poll();
        struct timespec pause = { 0, 1000000 };
        nanosleep(&pause, NULL);
    }
}

static TsonicStreamRead *start(int descriptor, size_t size, int64_t offset, int positioned) {
    int status = 99;
    TsonicStreamRead *request = tsonic_node_stream_read_start(descriptor, size, offset, positioned, &status);
    assert(request != NULL && status == 0);
    return request;
}

static void pending_pipe(void) {
    int descriptors[2];
    assert(pipe(descriptors) == 0);
    int flags = fcntl(descriptors[0], F_GETFL);
    TsonicStreamRead *request = start(descriptors[0], 32, 0, 0);
    int64_t begin = now_ns();
    for (int index = 0; index < 100; index++) {
        tsonic_node_stream_read_poll();
        assert(!tsonic_node_stream_read_ready(request));
    }
    assert(now_ns() - begin < 1000000000);
    assert(fcntl(descriptors[0], F_GETFL) == flags);
    assert(tsonic_node_stream_read_result(request) == UV_EAGAIN);
    assert(tsonic_node_stream_read_copy(request, NULL, 0) == UV_EAGAIN);
    assert(close(descriptors[0]) == 0);
    assert(write(descriptors[1], "a\0b", 3) == 3);
    wait_ready(request);
    assert(tsonic_node_stream_read_result(request) == 3);
    assert(tsonic_node_stream_read_error(request) == NULL);
    char output[4] = { 0, 0, 0, 99 };
    assert(tsonic_node_stream_read_copy(request, output, 2) == UV_EINVAL);
    assert(output[3] == 99);
    assert(tsonic_node_stream_read_copy(request, NULL, 3) == UV_EINVAL);
    assert(tsonic_node_stream_read_copy(request, output, 3) == 0);
    assert(memcmp(output, "a\0b", 3) == 0 && output[3] == 99);
    tsonic_node_stream_read_drop(request);
    close(descriptors[1]);
}

static void eof_and_offsets(void) {
    FILE *file = tmpfile();
    assert(file != NULL);
    int descriptor = fileno(file);
    assert(write(descriptor, "0123456789", 10) == 10);
    assert(lseek(descriptor, 4, SEEK_SET) == 4);
    TsonicStreamRead *request = start(descriptor, 3, 7, 1);
    wait_ready(request);
    char output[4] = { 0 };
    assert(tsonic_node_stream_read_result(request) == 3);
    assert(tsonic_node_stream_read_copy(request, output, 3) == 0);
    assert(strcmp(output, "789") == 0);
    assert(lseek(descriptor, 0, SEEK_CUR) == 4);
    tsonic_node_stream_read_drop(request);
    request = start(descriptor, 3, 0, 0);
    wait_ready(request);
    assert(tsonic_node_stream_read_copy(request, output, 3) == 0);
    assert(strcmp(output, "456") == 0);
    assert(lseek(descriptor, 0, SEEK_CUR) == 7);
    tsonic_node_stream_read_drop(request);
    request = start(descriptor, 4, 10, 1);
    wait_ready(request);
    assert(tsonic_node_stream_read_result(request) == 0);
    assert(tsonic_node_stream_read_copy(request, NULL, 0) == 0);
    tsonic_node_stream_read_drop(request);
    fclose(file);
}

static void errors_and_cancellation(void) {
    int status = 0;
    assert(tsonic_node_stream_read_start(-1, 1, 0, 0, &status) == NULL && status == UV_EINVAL);
    int descriptor = open("/dev/null", O_WRONLY | O_CLOEXEC);
    assert(descriptor >= 0);
    assert(tsonic_node_stream_read_start(descriptor, 0, 0, 0, &status) == NULL && status == UV_EINVAL);
    assert(tsonic_node_stream_read_start(descriptor, 1048577, 0, 0, &status) == NULL && status == UV_EINVAL);
    assert(tsonic_node_stream_read_start(descriptor, 1, -1, 1, &status) == NULL && status == UV_EINVAL);
    TsonicStreamRead *request = start(descriptor, 1, 0, 0);
    close(descriptor);
    wait_ready(request);
    assert(tsonic_node_stream_read_result(request) == UV_EBADF);
    assert(tsonic_node_stream_read_error(request) != NULL);
    tsonic_node_stream_read_drop(request);
    int descriptors[2];
    assert(pipe(descriptors) == 0);
    request = start(descriptors[0], 16, 0, 0);
    tsonic_node_stream_read_drop(request);
    close(descriptors[0]);
    close(descriptors[1]);
    descriptor = open("/dev/null", O_RDONLY | O_CLOEXEC);
    assert(descriptor >= 0);
    request = start(descriptor, 1, 0, 0);
    wait_ready(request);
    assert(tsonic_node_stream_read_result(request) == 0);
    tsonic_node_stream_read_drop(request);
    close(descriptor);
}

static void retained_budgets(void) {
    int descriptor = open("/dev/null", O_RDONLY | O_CLOEXEC);
    assert(descriptor >= 0);
    TsonicStreamRead *requests[256];
    int status = 0;
    for (int index = 0; index < 256; index++) {
        requests[index] = start(descriptor, 1, 0, 0);
        wait_ready(requests[index]);
    }
    assert(tsonic_node_stream_read_start(descriptor, 1, 0, 0, &status) == NULL && status == UV_ENOBUFS);
    for (int index = 0; index < 256; index++) tsonic_node_stream_read_drop(requests[index]);
    for (int index = 0; index < 64; index++) {
        requests[index] = start(descriptor, 1048576, 0, 0);
        wait_ready(requests[index]);
    }
    assert(tsonic_node_stream_read_start(descriptor, 1, 0, 0, &status) == NULL && status == UV_ENOBUFS);
    for (int index = 0; index < 64; index++) tsonic_node_stream_read_drop(requests[index]);
    TsonicStreamRead *request = start(descriptor, 1, 0, 0);
    wait_ready(request);
    tsonic_node_stream_read_drop(request);
    close(descriptor);
}

static void idle_pipes_do_not_starve_files(void) {
    int descriptors[33][2];
    TsonicStreamRead *requests[32];
    for (int index = 0; index < 32; index++) {
        assert(pipe(descriptors[index]) == 0);
        requests[index] = start(descriptors[index][0], 1, 0, 0);
    }
    assert(pipe(descriptors[32]) == 0);
    int status = 0;
    assert(tsonic_node_stream_read_start(descriptors[32][0], 1, 0, 0, &status) == NULL && status == UV_ENOBUFS);
    FILE *file = tmpfile();
    assert(file != NULL);
    assert(write(fileno(file), "x", 1) == 1);
    TsonicStreamRead *regular = start(fileno(file), 1, 0, 1);
    wait_ready(regular);
    assert(tsonic_node_stream_read_result(regular) == 1);
    char byte = 0;
    assert(tsonic_node_stream_read_copy(regular, &byte, 1) == 0 && byte == 'x');
    tsonic_node_stream_read_drop(regular);
    fclose(file);
    for (int index = 0; index < 32; index++) {
        close(descriptors[index][1]);
        wait_ready(requests[index]);
        assert(tsonic_node_stream_read_result(requests[index]) == 0);
        tsonic_node_stream_read_drop(requests[index]);
        close(descriptors[index][0]);
    }
    close(descriptors[32][0]);
    close(descriptors[32][1]);
}

int main(void) {
    alarm(30);
    assert(setenv("UV_THREADPOOL_SIZE", "2", 1) == 0);
    idle_pipes_do_not_starve_files();
    pending_pipe();
    eof_and_offsets();
    retained_budgets();
    errors_and_cancellation();
    return 0;
}
