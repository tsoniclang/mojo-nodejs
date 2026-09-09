#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

int tsonic_node_fs_open(const char* path, const char* flags, uint32_t mode) {
  int access;
  if (strcmp(flags, "r") == 0) access = O_RDONLY;
  else if (strcmp(flags, "r+") == 0) access = O_RDWR;
  else if (strcmp(flags, "rs") == 0) access = O_RDONLY | O_SYNC;
  else if (strcmp(flags, "rs+") == 0) access = O_RDWR | O_SYNC;
  else if (strcmp(flags, "w") == 0) access = O_WRONLY | O_CREAT | O_TRUNC;
  else if (strcmp(flags, "wx") == 0) access = O_WRONLY | O_CREAT | O_TRUNC | O_EXCL;
  else if (strcmp(flags, "w+") == 0) access = O_RDWR | O_CREAT | O_TRUNC;
  else if (strcmp(flags, "wx+") == 0) access = O_RDWR | O_CREAT | O_TRUNC | O_EXCL;
  else if (strcmp(flags, "a") == 0) access = O_WRONLY | O_CREAT | O_APPEND;
  else if (strcmp(flags, "ax") == 0) access = O_WRONLY | O_CREAT | O_APPEND | O_EXCL;
  else if (strcmp(flags, "a+") == 0) access = O_RDWR | O_CREAT | O_APPEND;
  else if (strcmp(flags, "ax+") == 0) access = O_RDWR | O_CREAT | O_APPEND | O_EXCL;
  else if (strcmp(flags, "as") == 0) access = O_WRONLY | O_CREAT | O_APPEND | O_SYNC;
  else if (strcmp(flags, "as+") == 0) access = O_RDWR | O_CREAT | O_APPEND | O_SYNC;
  else { errno = EINVAL; return -1; }
  int descriptor;
  do { descriptor = open(path, access | O_CLOEXEC, (mode_t)mode); } while (descriptor < 0 && errno == EINTR);
  return descriptor;
}

int64_t tsonic_node_stream_read(int descriptor, void* data, size_t size, int64_t offset, int positioned) {
  ssize_t result;
  do { result = positioned ? pread(descriptor, data, size, (off_t)offset) : read(descriptor, data, size); }
  while (result < 0 && errno == EINTR);
  return result;
}

int64_t tsonic_node_stream_write(int descriptor, const void* data, size_t size, int64_t offset, int positioned) {
  ssize_t result;
  do { result = positioned ? pwrite(descriptor, data, size, (off_t)offset) : write(descriptor, data, size); }
  while (result < 0 && errno == EINTR);
  return result;
}
