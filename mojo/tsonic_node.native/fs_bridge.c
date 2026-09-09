#define _POSIX_C_SOURCE 200809L
#include "fs_metadata.h"
#include <errno.h>
#include <string.h>

void* tsonic_node_fs_stat(const char* path, int descriptor, int follow, int* status) {
  uv_fs_t request;
  *status = path ? (follow ? uv_fs_stat(NULL, &request, path, NULL)
    : uv_fs_lstat(NULL, &request, path, NULL))
    : uv_fs_fstat(NULL, &request, descriptor, NULL);
  uv_stat_t* result = NULL;
  if (*status == 0) {
    result = malloc(sizeof(uv_stat_t));
    if (result) *result = request.statbuf;
    else *status = UV_ENOMEM;
  }
  uv_fs_req_cleanup(&request);
  return result;
}

void tsonic_node_fs_free(void* value) { free(value); }
int64_t tsonic_node_fs_stat_field(void* value, int field) { return fs_stat_field(value, field); }
double tsonic_node_fs_stat_time(void* value, int field) { return fs_stat_time(value, field); }

int tsonic_node_fs_access(const char* path, int mode) {
  uv_fs_t request;
  int status = uv_fs_access(NULL, &request, path, mode, NULL);
  uv_fs_req_cleanup(&request);
  return status;
}

int tsonic_node_fs_chmod(const char* path, int mode) {
  uv_fs_t request;
  int status = uv_fs_chmod(NULL, &request, path, mode, NULL);
  uv_fs_req_cleanup(&request);
  return status;
}

int tsonic_node_fs_copy(const char* source, const char* destination, int flags) {
  uv_fs_t request;
  int status = uv_fs_copyfile(NULL, &request, source, destination, flags, NULL);
  uv_fs_req_cleanup(&request);
  return status;
}

void* tsonic_node_fs_readlink(const char* path, size_t* length, int* status) {
  uv_fs_t request;
  *status = uv_fs_readlink(NULL, &request, path, NULL);
  char* result = NULL;
  *length = 0;
  if (*status == 0) {
    *length = strlen(request.ptr);
    result = malloc(*length + 1);
    if (result) memcpy(result, request.ptr, *length + 1);
    else *status = UV_ENOMEM;
  }
  uv_fs_req_cleanup(&request);
  return result;
}

static int remove_once(const char* path, int recursive) {
  uv_fs_t request;
  int status = uv_fs_lstat(NULL, &request, path, NULL);
  int directory = status == 0 && S_ISDIR(request.statbuf.st_mode);
  uv_fs_req_cleanup(&request);
  if (status < 0) return status;
  if (!directory) {
    status = uv_fs_unlink(NULL, &request, path, NULL);
    uv_fs_req_cleanup(&request);
    return status;
  }
  if (!recursive) return UV_EISDIR;
  status = uv_fs_scandir(NULL, &request, path, 0, NULL);
  if (status >= 0) {
    uv_dirent_t entry;
    size_t prefix = strlen(path);
    while ((status = uv_fs_scandir_next(&request, &entry)) == 0) {
      size_t length = strlen(entry.name);
      if (prefix > SIZE_MAX - length - 2) { status = UV_ENOMEM; break; }
      char* child = malloc(prefix + length + 2);
      if (!child) { status = UV_ENOMEM; break; }
      memcpy(child, path, prefix);
      child[prefix] = '/';
      memcpy(child + prefix + 1, entry.name, length + 1);
      status = remove_once(child, 1);
      free(child);
      if (status < 0 && status != UV_ENOENT) break;
    }
    if (status == UV_EOF) status = 0;
  }
  uv_fs_req_cleanup(&request);
  if (status < 0) return status;
  status = uv_fs_rmdir(NULL, &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return status;
}

int tsonic_node_fs_remove(const char* path, int recursive, int force,
    uint32_t retries, uint32_t delay) {
  uint32_t attempt = 0;
  for (;;) {
    int status = remove_once(path, recursive);
    if (status == 0 || (force && status == UV_ENOENT)) return 0;
    if (!recursive || attempt == retries ||
        (status != UV_EBUSY && status != UV_EMFILE && status != UV_ENFILE &&
         status != UV_ENOTEMPTY && status != UV_EPERM)) return status;
    ++attempt;
    uint64_t remaining = (uint64_t)delay * attempt;
    while (remaining != 0) {
      unsigned int interval = remaining > UINT32_MAX ? UINT32_MAX : (unsigned int)remaining;
      uv_sleep(interval);
      remaining -= interval;
    }
  }
}
