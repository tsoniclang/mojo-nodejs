#ifndef TSONIC_NODE_WORKER_API_H
#define TSONIC_NODE_WORKER_API_H

#include <stddef.h>
#include <stdint.h>

typedef struct TsonicWorkerChannel TsonicWorkerChannel;

int tsonic_node_worker_pair(TsonicWorkerChannel **first, TsonicWorkerChannel **second);
TsonicWorkerChannel *tsonic_node_worker_spawn(const char *arguments, size_t arguments_length, const char *environment, size_t environment_length, int inherit_environment, int *status);
TsonicWorkerChannel *tsonic_node_worker_adopt(int *status);
int tsonic_node_worker_send(TsonicWorkerChannel *channel, uint8_t kind, const uint8_t *bytes, size_t length);
int tsonic_node_worker_progress(TsonicWorkerChannel *channel);
int tsonic_node_worker_message(TsonicWorkerChannel *channel, uint8_t *kind, const uint8_t **bytes, size_t *length);
void tsonic_node_worker_consume(TsonicWorkerChannel *channel);
int tsonic_node_worker_pending(TsonicWorkerChannel *channel);
int tsonic_node_worker_closed(TsonicWorkerChannel *channel);
int tsonic_node_worker_exit(TsonicWorkerChannel *channel, int *code);
int tsonic_node_worker_id(TsonicWorkerChannel *channel);
int tsonic_node_worker_self_id(void);
int tsonic_node_worker_name(const char *name);
int tsonic_node_worker_terminate(TsonicWorkerChannel *channel);
int tsonic_node_worker_flush(TsonicWorkerChannel *channel, int timeout_ms);
int tsonic_node_worker_wait(TsonicWorkerChannel *channel, int timeout_ms);
void tsonic_node_worker_close(TsonicWorkerChannel *channel);
void tsonic_node_worker_free(TsonicWorkerChannel *channel);

#endif
