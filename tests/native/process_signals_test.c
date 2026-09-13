#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <uv.h>

int tsonic_node_signal_number(const char* name);

int main(void) {
    assert(tsonic_node_signal_number("SIGTERM") == SIGTERM);
    assert(tsonic_node_signal_number("SIGCONT") == SIGCONT);
    assert(tsonic_node_signal_number("invalid") == -1);
    int channel[2];
    assert(pipe(channel) == 0);
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        close(channel[0]);
        signal(SIGUSR1, SIG_DFL);
        assert(write(channel[1], "ready", 5) == 5);
        for (;;) pause();
    }
    close(channel[1]);
    char ready[5];
    assert(read(channel[0], ready, sizeof(ready)) == sizeof(ready));
    close(channel[0]);
    assert(uv_kill(child, 0) == 0);
    assert(uv_kill(child, tsonic_node_signal_number("SIGUSR1")) == 0);
    int status;
    assert(waitpid(child, &status, 0) == child);
    assert(WIFSIGNALED(status) && WTERMSIG(status) == SIGUSR1);
    return 0;
}
