#ifndef TSONIC_NODE_WORKER_MODEL_H
#define TSONIC_NODE_WORKER_MODEL_H

#include "api.h"
#include <sys/types.h>

#define TSONIC_WORKER_FRAME_LIMIT (16u * 1024u * 1024u + 1u)
#define TSONIC_WORKER_QUEUE_LIMIT (64u * 1024u * 1024u)
#define TSONIC_WORKER_FD_ENV "TSONIC_MOJO_WORKER_CHANNEL"

typedef struct TsonicWorkerFrame {
    struct TsonicWorkerFrame *next;
    size_t length;
    size_t offset;
    uint8_t bytes[];
} TsonicWorkerFrame;

struct TsonicWorkerChannel {
    int descriptor;
    int failure;
    int write_failure;
    int eof;
    pid_t process;
    int exited;
    int exit_code;
    TsonicWorkerFrame *out_first;
    TsonicWorkerFrame *out_last;
    size_t out_bytes;
    TsonicWorkerFrame *incoming;
    uint8_t header[4];
    size_t header_size;
};

TsonicWorkerChannel *tsonic_worker_channel_from_fd(int descriptor);

#endif
