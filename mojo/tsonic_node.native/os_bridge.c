#define _POSIX_C_SOURCE 200809L
#include <uv.h>
#include <errno.h>
#include <stdint.h>
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
