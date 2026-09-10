#define _POSIX_C_SOURCE 200809L
#include "fs_metadata.h"
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

typedef struct FsEvent {
  struct FsEvent* next;
  char* filename;
  int flags;
  int error;
  uv_stat_t current;
  uv_stat_t previous;
} FsEvent;

typedef struct {
  union { uv_fs_event_t event; uv_fs_poll_t poll; } handle;
  int polling;
  int queue_error;
  FsEvent* head;
  FsEvent* tail;
} FsWatcher;

static uv_loop_t watch_loop;
static int watch_loop_initialized;

static FsEvent* enqueue(FsWatcher* watcher) {
  FsEvent* event = calloc(1, sizeof(FsEvent));
  if (!event) { watcher->queue_error = ENOMEM; return NULL; }
  if (watcher->tail) watcher->tail->next = event;
  else watcher->head = event;
  watcher->tail = event;
  return event;
}

static void changed(uv_fs_event_t* handle, const char* filename, int flags, int status) {
  FsWatcher* watcher = handle->data;
  FsEvent* event = enqueue(watcher);
  if (!event) return;
  event->flags = flags;
  event->error = status < 0 ? -status : 0;
  if (filename) {
    size_t length = strlen(filename);
    event->filename = malloc(length + 1);
    if (!event->filename) { event->error = ENOMEM; return; }
    memcpy(event->filename, filename, length + 1);
  }
}

static void stat_changed(uv_fs_poll_t* handle, int status,
    const uv_stat_t* previous, const uv_stat_t* current) {
  FsEvent* event = enqueue(handle->data);
  if (!event) return;
  if (previous) event->previous = *previous;
  if (status == 0 && current) event->current = *current;
}

void tsonic_node_fs_event_free(void* pointer) {
  FsEvent* event = pointer;
  if (!event) return;
  free(event->filename);
  free(event);
}

static void closed(uv_handle_t* handle) {
  FsWatcher* watcher = handle->data;
  while (watcher->head) {
    FsEvent* event = watcher->head;
    watcher->head = event->next;
    tsonic_node_fs_event_free(event);
  }
  free(watcher);
}

void* tsonic_node_fs_watch_new(const char* path, int polling,
    unsigned int interval, int recursive, int persistent) {
  if (!watch_loop_initialized) {
    int status = uv_loop_init(&watch_loop);
    if (status < 0) { errno = -status; return NULL; }
    watch_loop_initialized = 1;
  }
  FsWatcher* watcher = calloc(1, sizeof(FsWatcher));
  if (!watcher) { errno = ENOMEM; return NULL; }
  watcher->polling = polling;
  int status = polling ? uv_fs_poll_init(&watch_loop, &watcher->handle.poll)
    : uv_fs_event_init(&watch_loop, &watcher->handle.event);
  if (status < 0) { free(watcher); errno = -status; return NULL; }
  uv_handle_t* handle = (uv_handle_t*)&watcher->handle;
  handle->data = watcher;
  status = polling
    ? uv_fs_poll_start(&watcher->handle.poll, stat_changed, path, interval)
    : uv_fs_event_start(&watcher->handle.event, changed, path, recursive ? UV_FS_EVENT_RECURSIVE : 0);
  if (status < 0) { uv_close(handle, closed); errno = -status; return NULL; }
  if (!persistent) uv_unref(handle);
  return watcher;
}

void tsonic_node_fs_watch_close(void* pointer) {
  FsWatcher* watcher = pointer;
  uv_handle_t* handle = (uv_handle_t*)&watcher->handle;
  if (uv_is_closing(handle)) return;
  if (watcher->polling) uv_fs_poll_stop(&watcher->handle.poll);
  else uv_fs_event_stop(&watcher->handle.event);
  uv_close(handle, closed);
}

void tsonic_node_fs_watch_ref(void* pointer, int referenced) {
  uv_handle_t* handle = (uv_handle_t*)&((FsWatcher*)pointer)->handle;
  if (referenced) uv_ref(handle);
  else uv_unref(handle);
}

int tsonic_node_fs_watch_has_ref(void* pointer) {
  return uv_has_ref((uv_handle_t*)&((FsWatcher*)pointer)->handle);
}

int tsonic_node_fs_watch_alive(void) {
  return watch_loop_initialized && uv_loop_alive(&watch_loop);
}

void tsonic_node_fs_watch_poll(void) {
  if (watch_loop_initialized) uv_run(&watch_loop, UV_RUN_NOWAIT);
}

int tsonic_node_fs_watch_error(void* pointer) {
  FsWatcher* watcher = pointer;
  int error = watcher->queue_error;
  watcher->queue_error = 0;
  return error;
}

void* tsonic_node_fs_watch_next(void* pointer) {
  FsWatcher* watcher = pointer;
  FsEvent* event = watcher->head;
  if (!event) return NULL;
  watcher->head = event->next;
  if (!watcher->head) watcher->tail = NULL;
  event->next = NULL;
  return event;
}

int tsonic_node_fs_event_error(void* pointer) { return ((FsEvent*)pointer)->error; }
int tsonic_node_fs_event_rename(void* pointer) { return (((FsEvent*)pointer)->flags & UV_RENAME) != 0; }
const char* tsonic_node_fs_event_filename(void* pointer, size_t* length) {
  const char* filename = ((FsEvent*)pointer)->filename;
  *length = filename ? strlen(filename) : 0;
  return filename;
}

int64_t tsonic_node_fs_event_stat(void* pointer, int previous, int field) {
  const uv_stat_t* value = previous ? &((FsEvent*)pointer)->previous : &((FsEvent*)pointer)->current;
  return fs_stat_field(value, field);
}

double tsonic_node_fs_event_time(void* pointer, int previous, int field) {
  const uv_stat_t* value = previous ? &((FsEvent*)pointer)->previous : &((FsEvent*)pointer)->current;
  return fs_stat_time(value, field);
}
