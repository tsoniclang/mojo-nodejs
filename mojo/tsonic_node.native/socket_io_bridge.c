#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <sys/socket.h>
#include <unistd.h>
#include <uv.h>

int tsonic_node_socket_nonblocking(int descriptor) {
    int flags = fcntl(descriptor, F_GETFL);
    int descriptor_flags = fcntl(descriptor, F_GETFD);
    if (flags < 0 || descriptor_flags < 0 ||
        fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) < 0 ||
        fcntl(descriptor, F_SETFD, descriptor_flags | FD_CLOEXEC) < 0) return -1;
    return 0;
}

int tsonic_node_socket_accept(int listener, int *status) {
    int descriptor;
    do { descriptor = accept(listener, NULL, NULL); } while (descriptor < 0 && errno == EINTR);
    *status = 0;
    if (descriptor < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) return -2;
        *status = uv_translate_sys_error(errno);
        return -1;
    }
    if (tsonic_node_socket_nonblocking(descriptor) < 0) {
        *status = uv_translate_sys_error(errno);
        close(descriptor);
        return -1;
    }
    return descriptor;
}

int64_t tsonic_node_socket_read(int descriptor, void *bytes, size_t capacity) {
    ssize_t count;
    do { count = recv(descriptor, bytes, capacity, MSG_DONTWAIT); } while (count < 0 && errno == EINTR);
    if (count >= 0) return count;
    if (errno == EAGAIN || errno == EWOULDBLOCK) return -2;
    return -1;
}

int64_t tsonic_node_socket_write(int descriptor, const void *bytes, size_t length) {
    ssize_t count;
    do { count = send(descriptor, bytes, length, MSG_DONTWAIT | MSG_NOSIGNAL); } while (count < 0 && errno == EINTR);
    if (count >= 0) return count;
    if (errno == EAGAIN || errno == EWOULDBLOCK) return -2;
    return -1;
}

int tsonic_node_socket_readable(int descriptor) {
    struct pollfd request = {descriptor, POLLIN, 0};
    int result;
    do { result = poll(&request, 1u, 0); } while (result < 0 && errno == EINTR);
    return result < 0 ? -1 : result > 0 && request.revents != 0;
}
