#define _POSIX_C_SOURCE 200809L
#include "model.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

TsonicWorkerChannel *tsonic_worker_channel_from_fd(int descriptor) {
    TsonicWorkerChannel *channel = calloc(1, sizeof(*channel));
    if (channel == NULL) { close(descriptor); return NULL; }
    int flags = fcntl(descriptor, F_GETFL);
    if (flags < 0 || fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) < 0 ||
        fcntl(descriptor, F_SETFD, FD_CLOEXEC) < 0) {
        close(descriptor);
        free(channel);
        return NULL;
    }
    channel->descriptor = descriptor;
    return channel;
}

int tsonic_node_worker_pair(TsonicWorkerChannel **first, TsonicWorkerChannel **second) {
    if (first == NULL || second == NULL) return EINVAL;
    *first = NULL;
    *second = NULL;
    int descriptors[2];
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, descriptors) != 0) return errno;
    *first = tsonic_worker_channel_from_fd(descriptors[0]);
    *second = tsonic_worker_channel_from_fd(descriptors[1]);
    if (*first == NULL || *second == NULL) {
        tsonic_node_worker_free(*first);
        tsonic_node_worker_free(*second);
        *first = NULL;
        *second = NULL;
        return ENOMEM;
    }
    return 0;
}

static int fail(TsonicWorkerChannel *channel, int status) {
    channel->failure = status;
    return status;
}

static void discard_output(TsonicWorkerChannel *channel) {
    while (channel->out_first != NULL) {
        TsonicWorkerFrame *frame = channel->out_first;
        channel->out_first = frame->next;
        free(frame);
    }
    channel->out_last = NULL;
    channel->out_bytes = 0;
}

static int fail_write(TsonicWorkerChannel *channel, int status) {
    channel->write_failure = status;
    discard_output(channel);
    return status;
}

int tsonic_node_worker_send(TsonicWorkerChannel *channel, uint8_t kind, const uint8_t *bytes, size_t length) {
    if (channel == NULL || channel->descriptor < 0 || channel->eof) return EPIPE;
    if (channel->failure != 0) return channel->failure;
    if (channel->write_failure != 0) return channel->write_failure;
    if ((length != 0 && bytes == NULL) || length >= TSONIC_WORKER_FRAME_LIMIT) return EMSGSIZE;
    size_t size = length + 5;
    if (size > TSONIC_WORKER_QUEUE_LIMIT - channel->out_bytes) return ENOBUFS;
    TsonicWorkerFrame *frame = malloc(sizeof(*frame) + size);
    if (frame == NULL) return ENOMEM;
    frame->next = NULL;
    frame->length = size;
    frame->offset = 0;
    uint32_t payload = (uint32_t)length + 1;
    for (size_t index = 0; index < 4; index++) frame->bytes[index] = (uint8_t)(payload >> (index * 8));
    frame->bytes[4] = kind;
    if (length != 0) memcpy(frame->bytes + 5, bytes, length);
    if (channel->out_last == NULL) channel->out_first = frame;
    else channel->out_last->next = frame;
    channel->out_last = frame;
    channel->out_bytes += size;
    int status = tsonic_node_worker_progress(channel);
    return status != 0 ? status : channel->write_failure;
}

static int write_pending(TsonicWorkerChannel *channel) {
    size_t budget = 256 * 1024;
    while (channel->out_first != NULL && budget != 0) {
        TsonicWorkerFrame *frame = channel->out_first;
        size_t size = frame->length - frame->offset;
        if (size > budget) size = budget;
        ssize_t written = send(channel->descriptor, frame->bytes + frame->offset, size, MSG_NOSIGNAL);
        if (written < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return fail_write(channel, errno);
        }
        if (written == 0) return fail_write(channel, EPIPE);
        frame->offset += (size_t)written;
        channel->out_bytes -= (size_t)written;
        budget -= (size_t)written;
        if (frame->offset == frame->length) {
            channel->out_first = frame->next;
            if (channel->out_first == NULL) channel->out_last = NULL;
            free(frame);
        }
    }
    return 0;
}

static int read_pending(TsonicWorkerChannel *channel) {
    if (channel->eof) return 0;
    for (size_t turn = 0; turn < 8; turn++) {
        if (channel->incoming != NULL && channel->incoming->offset == channel->incoming->length) return 0;
        uint8_t *destination;
        size_t size;
        if (channel->incoming == NULL) {
            destination = channel->header + channel->header_size;
            size = 4 - channel->header_size;
        } else {
            destination = channel->incoming->bytes + channel->incoming->offset;
            size = channel->incoming->length - channel->incoming->offset;
        }
        if (size > 64 * 1024) size = 64 * 1024;
        ssize_t received = recv(channel->descriptor, destination, size, 0);
        if (received < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return fail(channel, errno);
        }
        if (received == 0) {
            channel->eof = 1;
            if (channel->header_size != 0 || channel->incoming != NULL) return fail(channel, EPROTO);
            return 0;
        }
        if (channel->incoming != NULL) {
            channel->incoming->offset += (size_t)received;
        } else {
            channel->header_size += (size_t)received;
            if (channel->header_size == 4) {
                uint32_t length = 0;
                for (size_t index = 0; index < 4; index++) length |= (uint32_t)channel->header[index] << (index * 8);
                if (length == 0 || length > TSONIC_WORKER_FRAME_LIMIT) return fail(channel, EMSGSIZE);
                channel->incoming = malloc(sizeof(*channel->incoming) + length);
                if (channel->incoming == NULL) return fail(channel, ENOMEM);
                channel->incoming->length = length;
                channel->incoming->offset = 0;
                channel->incoming->next = NULL;
                channel->header_size = 0;
            }
        }
    }
    return 0;
}

int tsonic_node_worker_progress(TsonicWorkerChannel *channel) {
    if (channel == NULL || channel->descriptor < 0) return EBADF;
    if (channel->failure != 0) return channel->failure;
    int status = read_pending(channel);
    if (status != 0) return status;
    if (channel->eof && channel->out_first != NULL) fail_write(channel, EPIPE);
    if (!channel->eof && channel->write_failure == 0) write_pending(channel);
    return 0;
}

int tsonic_node_worker_message(TsonicWorkerChannel *channel, uint8_t *kind, const uint8_t **bytes, size_t *length) {
    if (channel == NULL || channel->incoming == NULL || channel->incoming->offset != channel->incoming->length) return 0;
    *kind = channel->incoming->bytes[0];
    *bytes = channel->incoming->bytes + 1;
    *length = channel->incoming->length - 1;
    return 1;
}

void tsonic_node_worker_consume(TsonicWorkerChannel *channel) {
    if (channel == NULL) return;
    free(channel->incoming);
    channel->incoming = NULL;
}

int tsonic_node_worker_pending(TsonicWorkerChannel *channel) {
    return channel != NULL && channel->out_first != NULL;
}

int tsonic_node_worker_closed(TsonicWorkerChannel *channel) {
    return channel == NULL || channel->descriptor < 0 || channel->eof;
}

int tsonic_node_worker_exit(TsonicWorkerChannel *channel, int *code) {
    if (channel == NULL || channel->process == 0) return 0;
    if (!channel->exited) {
        int status;
        pid_t result = waitpid(channel->process, &status, WNOHANG);
        if (result < 0) return errno == EINTR ? 0 : -errno;
        if (result == 0) return 0;
        channel->exited = 1;
        channel->exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;
    }
    *code = channel->exit_code;
    return 1;
}

int tsonic_node_worker_id(TsonicWorkerChannel *channel) { return channel == NULL ? 0 : (int)channel->process; }
int tsonic_node_worker_self_id(void) { return (int)getpid(); }

int tsonic_node_worker_terminate(TsonicWorkerChannel *channel) {
    if (channel == NULL || channel->process == 0 || channel->exited) return 0;
    return kill(channel->process, SIGKILL) == 0 || errno == ESRCH ? 0 : errno;
}

static int64_t milliseconds(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return -1;
    return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

int tsonic_node_worker_flush(TsonicWorkerChannel *channel, int timeout_ms) {
    if (channel == NULL) return EINVAL;
    if (channel->write_failure != 0) return channel->write_failure;
    int64_t start = milliseconds();
    if (start < 0 || timeout_ms < 0) return EINVAL;
    while (tsonic_node_worker_pending(channel)) {
        int status = tsonic_node_worker_progress(channel);
        if (status != 0) return status;
        if (channel->write_failure != 0) return channel->write_failure;
        if (!tsonic_node_worker_pending(channel)) return 0;
        int64_t remaining = timeout_ms - (milliseconds() - start);
        if (remaining <= 0) return ETIMEDOUT;
        struct pollfd descriptor = { channel->descriptor, POLLOUT, 0 };
        if (poll(&descriptor, 1, (int)remaining) < 0 && errno != EINTR) return errno;
    }
    return 0;
}

int tsonic_node_worker_wait(TsonicWorkerChannel *channel, int timeout_ms) {
    if (channel == NULL || timeout_ms < 0) return EINVAL;
    int64_t start = milliseconds();
    if (start < 0) return EINVAL;
    for (;;) {
        int status = tsonic_node_worker_progress(channel);
        if (status != 0) return status;
        if (channel->incoming != NULL && channel->incoming->offset == channel->incoming->length) return 0;
        if (channel->eof) return EPIPE;
        int64_t remaining = timeout_ms - (milliseconds() - start);
        if (remaining <= 0) return ETIMEDOUT;
        struct pollfd descriptor = { channel->descriptor, POLLIN, 0 };
        if (poll(&descriptor, 1, (int)remaining) < 0 && errno != EINTR) return errno;
    }
}

void tsonic_node_worker_close(TsonicWorkerChannel *channel) {
    if (channel == NULL) return;
    if (channel->descriptor >= 0) close(channel->descriptor);
    channel->descriptor = -1;
    discard_output(channel);
    tsonic_node_worker_consume(channel);
}

void tsonic_node_worker_free(TsonicWorkerChannel *channel) {
    if (channel == NULL) return;
    tsonic_node_worker_close(channel);
    if (channel->process != 0 && !channel->exited) {
        tsonic_node_worker_terminate(channel);
        while (waitpid(channel->process, NULL, 0) < 0 && errno == EINTR) {}
    }
    free(channel);
}
