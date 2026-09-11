#define _POSIX_C_SOURCE 200809L
#include <uv.h>
#include <errno.h>
#include <stdint.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>

char* tsonic_node_os_name(int field) {
  uv_utsname_t information;
  int status = uv_os_uname(&information);
  if (status != 0) { errno = -status; return NULL; }
  const char* source;
  switch (field) {
    case 0: source = information.sysname; break;
    case 1: source = information.release; break;
    case 2: source = information.version; break;
    case 3: source = information.machine; break;
    default: errno = EINVAL; return NULL;
  }
  size_t size = strlen(source) + 1;
  char* result = malloc(size);
  if (!result) { errno = ENOMEM; return NULL; }
  memcpy(result, source, size);
  return result;
}

int tsonic_node_os_little_endian(void) {
  const uint16_t marker = 1;
  return *(const unsigned char*)&marker == 1;
}

const char* tsonic_node_system_error(int code, int message) {
  switch (code) {
#define ERROR_TEXT(name, text) case UV_##name: return message ? text : #name;
    UV_ERRNO_MAP(ERROR_TEXT)
#undef ERROR_TEXT
    default: return NULL;
  }
}

int tsonic_node_signal_number(const char* name) {
  static const struct { const char* name; int number; } signals[] = {
#define SIGNAL_ENTRY(name) {#name, name}
    SIGNAL_ENTRY(SIGHUP), SIGNAL_ENTRY(SIGINT), SIGNAL_ENTRY(SIGQUIT),
    SIGNAL_ENTRY(SIGILL), SIGNAL_ENTRY(SIGABRT), SIGNAL_ENTRY(SIGFPE),
    SIGNAL_ENTRY(SIGKILL), SIGNAL_ENTRY(SIGSEGV), SIGNAL_ENTRY(SIGPIPE),
    SIGNAL_ENTRY(SIGALRM), SIGNAL_ENTRY(SIGTERM),
#ifdef SIGTRAP
    SIGNAL_ENTRY(SIGTRAP),
#endif
#ifdef SIGIOT
    SIGNAL_ENTRY(SIGIOT),
#endif
#ifdef SIGBUS
    SIGNAL_ENTRY(SIGBUS),
#endif
#ifdef SIGUSR1
    SIGNAL_ENTRY(SIGUSR1), SIGNAL_ENTRY(SIGUSR2),
#endif
#ifdef SIGCHLD
    SIGNAL_ENTRY(SIGCHLD),
#endif
#ifdef SIGCONT
    SIGNAL_ENTRY(SIGCONT), SIGNAL_ENTRY(SIGSTOP), SIGNAL_ENTRY(SIGTSTP),
    SIGNAL_ENTRY(SIGTTIN), SIGNAL_ENTRY(SIGTTOU),
#endif
#ifdef SIGURG
    SIGNAL_ENTRY(SIGURG),
#endif
#ifdef SIGXCPU
    SIGNAL_ENTRY(SIGXCPU), SIGNAL_ENTRY(SIGXFSZ),
#endif
#ifdef SIGVTALRM
    SIGNAL_ENTRY(SIGVTALRM), SIGNAL_ENTRY(SIGPROF),
#endif
#ifdef SIGWINCH
    SIGNAL_ENTRY(SIGWINCH),
#endif
#ifdef SIGIO
    SIGNAL_ENTRY(SIGIO),
#endif
#ifdef SIGPOLL
    SIGNAL_ENTRY(SIGPOLL),
#endif
#ifdef SIGPWR
    SIGNAL_ENTRY(SIGPWR),
#endif
#ifdef SIGSYS
    SIGNAL_ENTRY(SIGSYS),
#endif
#ifdef SIGSTKFLT
    SIGNAL_ENTRY(SIGSTKFLT),
#endif
#ifdef SIGINFO
    SIGNAL_ENTRY(SIGINFO),
#endif
#ifdef SIGBREAK
    SIGNAL_ENTRY(SIGBREAK),
#endif
#undef SIGNAL_ENTRY
  };
  for (size_t index = 0; index < sizeof(signals) / sizeof(signals[0]); ++index) {
    if (strcmp(name, signals[index].name) == 0) return signals[index].number;
  }
  return -1;
}
