#define _POSIX_C_SOURCE 200809L
#include "read.h"
#include <errno.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <uv.h>

#define STREAM_READ_LIMIT 256u
#define STREAM_READ_BYTES (64u * 1024u * 1024u)
#define STREAM_READ_CHUNK (1024u * 1024u)

struct TsonicStreamRead {
    atomic_uint references;
    atomic_int ready;
    uv_fs_t operation;
    int descriptor;
    char *bytes;
    size_t capacity;
    int64_t result;
};

static atomic_uint live_reads;
static atomic_size_t live_bytes;
static uv_once_t stream_once = UV_ONCE_INIT;
static uv_mutex_t stream_mutex;
static uv_loop_t stream_loop;
static int stream_status;
static size_t completed_reads;

static void initialize_stream_loop(void) {
    stream_status = uv_mutex_init(&stream_mutex);
    if (stream_status == 0) stream_status = uv_loop_init(&stream_loop);
}

static void release_read(TsonicStreamRead *request) {
    if (atomic_fetch_sub_explicit(&request->references, 1, memory_order_acq_rel) != 1) return;
    atomic_fetch_sub_explicit(&live_bytes, request->capacity, memory_order_relaxed);
    atomic_fetch_sub_explicit(&live_reads, 1, memory_order_relaxed);
    free(request->bytes);
    free(request);
}

static void complete_read(uv_fs_t *operation) {
    TsonicStreamRead *request = operation->data;
    request->result = operation->result;
    uv_fs_req_cleanup(operation);
    close(request->descriptor);
    request->descriptor = -1;
    completed_reads++;
    atomic_store_explicit(&request->ready, 1, memory_order_release);
    release_read(request);
}

TsonicStreamRead *tsonic_node_stream_read_start(int descriptor, size_t size, int64_t offset, int positioned, int *error) {
    if (error == NULL) return NULL;
    *error = 0;
    if (descriptor < 0 || size == 0 || size > STREAM_READ_CHUNK || (positioned && offset < 0)) {
        *error = UV_EINVAL;
        return NULL;
    }
    uv_once(&stream_once, initialize_stream_loop);
    if (stream_status != 0) {
        *error = stream_status;
        return NULL;
    }
    unsigned count = atomic_fetch_add_explicit(&live_reads, 1, memory_order_relaxed);
    if (count >= STREAM_READ_LIMIT) {
        atomic_fetch_sub_explicit(&live_reads, 1, memory_order_relaxed);
        *error = UV_ENOBUFS;
        return NULL;
    }
    size_t bytes = atomic_fetch_add_explicit(&live_bytes, size, memory_order_relaxed);
    if (bytes > STREAM_READ_BYTES - size) {
        atomic_fetch_sub_explicit(&live_bytes, size, memory_order_relaxed);
        atomic_fetch_sub_explicit(&live_reads, 1, memory_order_relaxed);
        *error = UV_ENOBUFS;
        return NULL;
    }
    TsonicStreamRead *request = calloc(1, sizeof(*request));
    if (request == NULL) {
        atomic_fetch_sub_explicit(&live_bytes, size, memory_order_relaxed);
        atomic_fetch_sub_explicit(&live_reads, 1, memory_order_relaxed);
        *error = UV_ENOMEM;
        return NULL;
    }
    atomic_init(&request->references, 2);
    atomic_init(&request->ready, 0);
    request->capacity = size;
    request->descriptor = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    int descriptor_error = request->descriptor < 0 ? uv_translate_sys_error(errno) : 0;
    request->bytes = malloc(size);
    if (request->descriptor < 0 || request->bytes == NULL) {
        *error = descriptor_error != 0 ? descriptor_error : UV_ENOMEM;
        if (request->descriptor >= 0) close(request->descriptor);
        release_read(request);
        release_read(request);
        return NULL;
    }
    request->operation.data = request;
    uv_buf_t buffer = uv_buf_init(request->bytes, (unsigned int)size);
    uv_mutex_lock(&stream_mutex);
    int status = uv_fs_read(&stream_loop, &request->operation, request->descriptor, &buffer, 1,
                            positioned ? offset : -1, complete_read);
    uv_mutex_unlock(&stream_mutex);
    if (status < 0) {
        *error = status;
        uv_fs_req_cleanup(&request->operation);
        close(request->descriptor);
        release_read(request);
        release_read(request);
        return NULL;
    }
    return request;
}

int tsonic_node_stream_read_poll(void) {
    uv_once(&stream_once, initialize_stream_loop);
    if (stream_status != 0) return 0;
    uv_mutex_lock(&stream_mutex);
    size_t previous = completed_reads;
    uv_run(&stream_loop, UV_RUN_NOWAIT);
    int progressed = previous != completed_reads;
    uv_mutex_unlock(&stream_mutex);
    return progressed;
}

int tsonic_node_stream_read_ready(TsonicStreamRead *request) {
    return request != NULL && atomic_load_explicit(&request->ready, memory_order_acquire);
}

int64_t tsonic_node_stream_read_result(TsonicStreamRead *request) {
    return tsonic_node_stream_read_ready(request) ? request->result : UV_EAGAIN;
}

const char *tsonic_node_stream_read_error(TsonicStreamRead *request) {
    int64_t result = tsonic_node_stream_read_result(request);
    return result < 0 ? uv_strerror((int)result) : NULL;
}

int tsonic_node_stream_read_copy(TsonicStreamRead *request, void *output, size_t size) {
    if (!tsonic_node_stream_read_ready(request) || request->result < 0) return UV_EAGAIN;
    if (size != (size_t)request->result || (size != 0 && output == NULL)) return UV_EINVAL;
    if (size != 0) memcpy(output, request->bytes, size);
    return 0;
}

void tsonic_node_stream_read_drop(TsonicStreamRead *request) {
    if (request == NULL) return;
    uv_mutex_lock(&stream_mutex);
    if (!tsonic_node_stream_read_ready(request)) uv_cancel((uv_req_t *)&request->operation);
    uv_mutex_unlock(&stream_mutex);
    release_read(request);
}
