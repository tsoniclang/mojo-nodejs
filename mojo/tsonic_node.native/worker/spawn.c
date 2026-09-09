#define _GNU_SOURCE
#include "model.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <spawn.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <uv.h>

extern char **environ;

static int vector(const char *packed, size_t length, char ***result, size_t *count) {
    *result = NULL;
    *count = 0;
    if (length > 1024 * 1024 || (length != 0 && (packed == NULL || packed[length - 1] != 0))) return EINVAL;
    for (size_t index = 0; index < length; index++) if (packed[index] == 0) (*count)++;
    if (*count > 16384) return E2BIG;
    char **items = calloc(*count + 1, sizeof(*items));
    if (items == NULL) return ENOMEM;
    size_t item = 0;
    size_t offset = 0;
    while (offset < length) {
        items[item++] = (char *)packed + offset;
        offset += strlen(packed + offset) + 1;
    }
    *result = items;
    return 0;
}

static int worker_variable(const char *value) {
    return strncmp(value, TSONIC_WORKER_FD_ENV "=", sizeof(TSONIC_WORKER_FD_ENV)) == 0;
}

TsonicWorkerChannel *tsonic_node_worker_spawn(const char *arguments, size_t arguments_length, const char *environment, size_t environment_length, int inherit_environment, int *status) {
    if (status == NULL) return NULL;
    *status = 0;
    char **supplied_arguments = NULL;
    char **supplied_environment = NULL;
    size_t argument_count = 0;
    size_t environment_count = 0;
    *status = vector(arguments, arguments_length, &supplied_arguments, &argument_count);
    if (*status != 0) return NULL;
    *status = vector(environment, environment_length, &supplied_environment, &environment_count);
    if (*status != 0) { free(supplied_arguments); return NULL; }
    char **base_environment = inherit_environment ? environ : supplied_environment;
    if (inherit_environment) {
        environment_count = 0;
        while (environ[environment_count] != NULL) environment_count++;
    }
    char **child_environment = calloc(environment_count + 2, sizeof(*child_environment));
    char **child_arguments = calloc(argument_count + 2, sizeof(*child_arguments));
    if (child_environment == NULL || child_arguments == NULL) { *status = ENOMEM; goto cleanup; }
    size_t retained = 0;
    for (size_t index = 0; index < environment_count; index++) {
        const char *entry = base_environment[index];
        const char *separator = strchr(entry, '=');
        if (separator == NULL || separator == entry) { *status = EINVAL; goto cleanup; }
        if (!worker_variable(entry)) child_environment[retained++] = base_environment[index];
    }
    child_environment[retained] = TSONIC_WORKER_FD_ENV "=3";
    char executable[PATH_MAX + 1];
    size_t path_length = sizeof(executable) - 1;
    int path_status = uv_exepath(executable, &path_length);
    if (path_status != 0) { *status = path_status == UV_ENOBUFS ? ENAMETOOLONG : EIO; goto cleanup; }
    executable[path_length] = 0;
    child_arguments[0] = executable;
    for (size_t index = 0; index < argument_count; index++) child_arguments[index + 1] = supplied_arguments[index];
    int descriptors[2];
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, descriptors) != 0) { *status = errno; goto cleanup; }
    posix_spawn_file_actions_t actions;
    *status = posix_spawn_file_actions_init(&actions);
    if (*status != 0) { close(descriptors[0]); close(descriptors[1]); goto cleanup; }
    *status = posix_spawn_file_actions_addclose(&actions, descriptors[0]);
    if (*status == 0) *status = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    if (*status == 0) *status = posix_spawn_file_actions_adddup2(&actions, descriptors[1], 3);
    if (*status == 0 && descriptors[1] != 3) *status = posix_spawn_file_actions_addclose(&actions, descriptors[1]);
    pid_t process = 0;
    if (*status == 0) *status = posix_spawn(&process, executable, &actions, NULL, child_arguments, child_environment);
    posix_spawn_file_actions_destroy(&actions);
    close(descriptors[1]);
    if (*status != 0) { close(descriptors[0]); goto cleanup; }
    TsonicWorkerChannel *channel = tsonic_worker_channel_from_fd(descriptors[0]);
    if (channel == NULL) {
        kill(process, SIGKILL);
        while (waitpid(process, NULL, 0) < 0 && errno == EINTR) {}
        *status = ENOMEM;
        goto cleanup;
    }
    channel->process = process;
    free(child_arguments);
    free(child_environment);
    free(supplied_environment);
    free(supplied_arguments);
    return channel;
cleanup:
    free(child_arguments);
    free(child_environment);
    free(supplied_environment);
    free(supplied_arguments);
    return NULL;
}

TsonicWorkerChannel *tsonic_node_worker_adopt(int *status) {
    if (status == NULL) return NULL;
    *status = 0;
    const char *value = getenv(TSONIC_WORKER_FD_ENV);
    if (value == NULL) return NULL;
    if (strcmp(value, "3") != 0) { *status = EINVAL; return NULL; }
    struct sockaddr_storage address;
    socklen_t address_size = sizeof(address);
    int socket_type = 0;
    socklen_t type_size = sizeof(socket_type);
    struct ucred credentials;
    socklen_t credentials_size = sizeof(credentials);
    if (getsockname(3, (struct sockaddr *)&address, &address_size) != 0 || address.ss_family != AF_UNIX ||
        getsockopt(3, SOL_SOCKET, SO_TYPE, &socket_type, &type_size) != 0 || socket_type != SOCK_STREAM ||
        getsockopt(3, SOL_SOCKET, SO_PEERCRED, &credentials, &credentials_size) != 0 ||
        credentials.uid != getuid() || credentials.pid != getppid()) {
        *status = EACCES;
        return NULL;
    }
    if (unsetenv(TSONIC_WORKER_FD_ENV) != 0) { *status = errno; return NULL; }
    TsonicWorkerChannel *channel = tsonic_worker_channel_from_fd(3);
    if (channel == NULL) *status = ENOMEM;
    return channel;
}

int tsonic_node_worker_name(const char *name) {
    if (name == NULL) return EINVAL;
    return prctl(PR_SET_NAME, name, 0, 0, 0) == 0 ? 0 : errno;
}
