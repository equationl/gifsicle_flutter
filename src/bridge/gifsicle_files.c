#include "gifsicle_bridge.h"
#include <stdio.h>
#if defined(_WIN32)
#include <windows.h>
#include <stdlib.h>
static wchar_t *wide(const char *s) {
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, NULL, 0);
  if (!n)
    return NULL;
  wchar_t *r = malloc((size_t)n * sizeof(wchar_t));
  if (!r)
    return NULL;
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, r, n)) {
    free(r);
    return NULL;
  }
  return r;
}
FILE *gs_fs_fopen(const char *path, const char *mode) {
  wchar_t *p = wide(path), *m = wide(mode);
  FILE *r = p && m ? _wfopen(p, m) : NULL;
  free(p);
  free(m);
  return r;
}
int32_t gs_publish_file(const char *source, const char *target, int32_t overwrite) {
  wchar_t *s = wide(source), *t = wide(target);
  int r = -1;
  if (s && t)
    r = MoveFileExW(s, t, MOVEFILE_WRITE_THROUGH | (overwrite ? MOVEFILE_REPLACE_EXISTING : 0))
            ? 0
            : (int)GetLastError();
  free(s);
  free(t);
  return r;
}
#else
#include <unistd.h>
#include <errno.h>
#if defined(__ANDROID__)
#include <fcntl.h>
#include <sys/syscall.h>
#endif
FILE *gs_fs_fopen(const char *path, const char *mode) { return fopen(path, mode); }
int32_t gs_publish_file(const char *source, const char *target, int32_t overwrite) {
  if (overwrite)
    return rename(source, target) == 0 ? 0 : errno;
#if defined(__ANDROID__)
  /* Android app domains can reject hard links. Atomic no-replace rename keeps
     the destination protected without creating a hard link or an empty file. */
  if (syscall(__NR_renameat2, AT_FDCWD, source, AT_FDCWD, target, 1 /* RENAME_NOREPLACE */))
    return errno;
  return 0;
#else
  if (link(source, target))
    return errno;
  unlink(source);
  return 0;
#endif
}
#endif
