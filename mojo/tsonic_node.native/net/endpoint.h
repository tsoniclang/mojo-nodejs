#ifndef TSONIC_NODE_NET_ENDPOINT_H
#define TSONIC_NODE_NET_ENDPOINT_H

#include <stddef.h>
#include <stdint.h>

typedef struct TsonicNetEndpoint TsonicNetEndpoint;

TsonicNetEndpoint *tsonic_node_net_endpoint_new(const char *host, int port, int listener);
TsonicNetEndpoint *tsonic_node_net_endpoint_adopt(int descriptor, int *status);
TsonicNetEndpoint *tsonic_node_net_endpoint_accept(TsonicNetEndpoint *listener, int *status);
void tsonic_node_net_endpoint_close(TsonicNetEndpoint *endpoint);
void tsonic_node_net_endpoint_free(TsonicNetEndpoint *endpoint);
int tsonic_node_net_endpoint_progress(TsonicNetEndpoint *endpoint);
int tsonic_node_net_endpoint_descriptor(const TsonicNetEndpoint *endpoint);
int tsonic_node_net_endpoint_address(const TsonicNetEndpoint *endpoint, int peer, char *address, size_t capacity, int *port, int *family);
int tsonic_node_net_endpoint_no_delay(TsonicNetEndpoint *endpoint, int enabled);
int tsonic_node_net_endpoint_shutdown(TsonicNetEndpoint *endpoint);
int tsonic_node_net_resolution_poll(void);
int tsonic_node_net_resolution_pending(void);

#endif
