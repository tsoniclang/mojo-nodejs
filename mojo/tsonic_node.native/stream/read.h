#ifndef TSONIC_NODE_STREAM_READ_H
#define TSONIC_NODE_STREAM_READ_H

#include <stddef.h>
#include <stdint.h>

typedef struct TsonicStreamRead TsonicStreamRead;
TsonicStreamRead *tsonic_node_stream_read_start(int descriptor, size_t size, int64_t offset, int positioned, int *error);
int tsonic_node_stream_read_poll(void);
int tsonic_node_stream_read_ready(TsonicStreamRead *request);
int64_t tsonic_node_stream_read_result(TsonicStreamRead *request);
const char *tsonic_node_stream_read_error(TsonicStreamRead *request);
int tsonic_node_stream_read_copy(TsonicStreamRead *request, void *output, size_t size);
void tsonic_node_stream_read_drop(TsonicStreamRead *request);

#endif
