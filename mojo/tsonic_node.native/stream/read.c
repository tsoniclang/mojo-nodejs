#define _POSIX_C_SOURCE 200809L
#include "read.h"
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <uv.h>

#define STREAM_READ_LIMIT 256u
#define STREAM_READ_BYTES (64u * 1024u * 1024u)
#define STREAM_READ_CHUNK (1024u * 1024u)
#define STREAM_WAIT_WORKERS 32u

struct TsonicStreamRead {
    atomic_uint references;
    atomic_int ready;
    uv_fs_t operation;
    int descriptor;
    char *bytes;
    size_t capacity;
    int64_t result;
    int worker_read;
    int positioned;
    int64_t offset;
};

static atomic_uint live_reads;
static atomic_size_t live_bytes;
static atomic_uint waiting_workers;
static uv_once_t stream_once = UV_ONCE_INIT;
static uv_mutex_t stream_mutex;
static uv_loop_t stream_loop;
static int stream_status;
static atomic_size_t completed_reads;

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

static void finish_read(TsonicStreamRead *request, int64_t result) {
    request->result = result;
    close(request->descriptor);
    request->descriptor = -1;
    atomic_fetch_add_explicit(&completed_reads, 1, memory_order_relaxed);
    atomic_store_explicit(&request->ready, 1, memory_order_release);
    release_read(request);
}

static void complete_read(uv_fs_t *operation) {
    TsonicStreamRead *request = operation->data;
    int64_t result = operation->result;
    uv_fs_req_cleanup(operation);
    finish_read(request, result);
}

static void *read_waiting_descriptor(void *context) {
    TsonicStreamRead *request = context;
    ssize_t result;
    do {
        result = request->positioned
            ? pread(request->descriptor, request->bytes, request->capacity, request->offset)
            : read(request->descriptor, request->bytes, request->capacity);
    } while (result < 0 && errno == EINTR);
    int64_t selected = result < 0 ? uv_translate_sys_error(errno) : result;
    atomic_fetch_sub_explicit(&waiting_workers, 1, memory_order_relaxed);
    finish_read(request, selected);
    return NULL;
}

static int start_waiting_read(TsonicStreamRead *request) {
    unsigned count = atomic_fetch_add_explicit(&waiting_workers, 1, memory_order_relaxed);
    if (count >= STREAM_WAIT_WORKERS) {
        atomic_fetch_sub_explicit(&waiting_workers, 1, memory_order_relaxed);
        return UV_ENOBUFS;
    }
    pthread_attr_t attributes;
    int status = pthread_attr_init(&attributes);
    if (status == 0) {
        status = pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
        if (status == 0) status = pthread_attr_setstacksize(&attributes, 256u * 1024u);
        if (status == 0) {
            pthread_t worker;
            status = pthread_create(&worker, &attributes, read_waiting_descriptor, request);
        }
        pthread_attr_destroy(&attributes);
    }
    if (status != 0) atomic_fetch_sub_explicit(&waiting_workers, 1, memory_order_relaxed);
    return status == 0 ? 0 : uv_translate_sys_error(status);
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
    request->positioned = positioned;
    request->offset = offset;
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
    struct stat metadata;
    int status = fstat(request->descriptor, &metadata);
    if (status < 0) {
        status = uv_translate_sys_error(errno);
    } else if (S_ISREG(metadata.st_mode)) {
        request->operation.data = request;
        uv_buf_t buffer = uv_buf_init(request->bytes, (unsigned int)size);
        uv_mutex_lock(&stream_mutex);
        status = uv_fs_read(&stream_loop, &request->operation, request->descriptor, &buffer, 1,
                            positioned ? offset : -1, complete_read);
        uv_mutex_unlock(&stream_mutex);
        if (status < 0) uv_fs_req_cleanup(&request->operation);
    } else {
        request->worker_read = 1;
        status = start_waiting_read(request);
    }
    if (status < 0) {
        *error = status;
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
    size_t previous = atomic_load_explicit(&completed_reads, memory_order_relaxed);
    uv_run(&stream_loop, UV_RUN_NOWAIT);
    int progressed = previous != atomic_load_explicit(&completed_reads, memory_order_relaxed);
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
    if (!request->worker_read && !tsonic_node_stream_read_ready(request)) uv_cancel((uv_req_t *)&request->operation);
    uv_mutex_unlock(&stream_mutex);
    release_read(request);
}
