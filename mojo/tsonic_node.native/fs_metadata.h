#ifndef TSONIC_NODE_FS_METADATA_H
#define TSONIC_NODE_FS_METADATA_H
#include <uv.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/stat.h>

static int64_t fs_stat_field(const uv_stat_t* value, int field) {
  switch (field) {
    case 0: return value->st_size;
    case 1: return value->st_mode;
    case 2: return value->st_dev;
    case 3: return value->st_ino;
    case 4: return value->st_nlink;
    case 5: return value->st_uid;
    case 6: return value->st_gid;
    case 7: return S_ISREG(value->st_mode);
    case 8: return S_ISDIR(value->st_mode);
    case 9: return S_ISLNK(value->st_mode);
    default: abort();
  }
}

static double fs_stat_time(const uv_stat_t* value, int field) {
  const uv_timespec_t* time;
  switch (field) {
    case 0: time = &value->st_atim; break;
    case 1: time = &value->st_mtim; break;
    case 2: time = &value->st_ctim; break;
    case 3: time = &value->st_birthtim; break;
    default: abort();
  }
  return (double)time->tv_sec * 1000.0 + (double)time->tv_nsec / 1000000.0;
}
#endif
