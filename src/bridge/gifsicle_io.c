#include "gifsicle_io.h"
#include "gifsicle_context.h"
#include <limits.h>
gs_io *gs_io_memory(const uint8_t *data, size_t length, int writable) {
  gs_io *io = calloc(1, sizeof(*io));
  if (!io)
    gs_fail(4, "out of memory creating stream");
  io->data = (unsigned char *)data;
  io->length = length;
  io->owned = writable;
  return io;
}
int gs_io_close(gs_io *io) {
  int r = 0;
  if (io) {
    if (io->disk)
      r = fclose(io->disk);
    if (io->owned)
      free(io->data);
    free(io);
  }
  return r;
}
void gs_io_destroy(gs_io *io) { (void)gs_io_close(io); }
size_t gs_fread(void *p, size_t size, size_t count, gs_io *io) {
  if (io->disk)
    return fread(p, size, count, io->disk);
  if (!size || !count)
    return 0;
  if (count > SIZE_MAX / size)
    gs_fail(1, "read length overflow");
  size_t n = size * count;
  if (n > io->length - io->position)
    n = io->length - io->position;
  if (n)
    memcpy(p, io->data + io->position, n);
  io->position += n;
  return n / size;
}
size_t gs_fwrite(const void *p, size_t size, size_t count, gs_io *io) {
  if (io->disk) {
    size_t n = fwrite(p, size, count, io->disk);
    if (n != count)
      gs_fail(6, "file write failed");
    return n;
  }
  if (!size || !count)
    return 0;
  if (!io->owned || count > SIZE_MAX / size || size * count > SIZE_MAX - io->position - 1)
    gs_fail(4, "output length overflow");
  size_t n = size * count, needed = io->position + n + 1;
  if (needed > io->capacity) {
    size_t cap = io->capacity ? io->capacity : 4096;
    while (cap < needed) {
      if (cap > SIZE_MAX / 2) {
        cap = needed;
        break;
      }
      cap *= 2;
    }
    unsigned char *b = realloc(io->data, cap);
    if (!b)
      gs_fail(4, "out of memory growing output");
    io->data = b;
    io->capacity = cap;
  }
  memcpy(io->data + io->position, p, n);
  io->position += n;
  if (io->position > io->length)
    io->length = io->position;
  io->data[io->length] = 0;
  return count;
}
int gs_getc(gs_io *io) {
  unsigned char c;
  return gs_fread(&c, 1, 1, io) == 1 ? c : EOF;
}
int gs_ungetc(int c, gs_io *io) {
  if (io->disk)
    return ungetc(c, io->disk);
  if (c == EOF || !io->position)
    return EOF;
  --io->position;
  return c;
}
int gs_putc(int c, gs_io *io) {
  unsigned char b = (unsigned char)c;
  return gs_fwrite(&b, 1, 1, io) == 1 ? b : EOF;
}
int gs_fputs(const char *s, gs_io *io) {
  return gs_fwrite(s, 1, strlen(s), io) == strlen(s) ? 0 : EOF;
}
char *gs_fgets(char *s, int n, gs_io *io) {
  if (n <= 0)
    return NULL;
  int i = 0, c;
  while (i < n - 1 && (c = gs_getc(io)) != EOF) {
    s[i++] = (char)c;
    if (c == '\n')
      break;
  }
  s[i] = 0;
  return i ? s : NULL;
}
int gs_vfprintf(gs_io *io, const char *fmt, va_list ap) {
  va_list copy;
  va_copy(copy, ap);
  int n = vsnprintf(NULL, 0, fmt, copy);
  va_end(copy);
  if (n < 0)
    return n;
  char *buf = gs_alloc((size_t)n + 1);
  vsnprintf(buf, (size_t)n + 1, fmt, ap);
  gs_fwrite(buf, 1, (size_t)n, io);
  gs_free(buf);
  return n;
}
int gs_fprintf(gs_io *io, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int n = gs_vfprintf(io, fmt, ap);
  va_end(ap);
  return n;
}
int gs_fflush(gs_io *io) { return io->disk && io->writable ? fflush(io->disk) : 0; }
int gs_fileno(gs_io *io) { return io->disk ? fileno(io->disk) : -1; }

int gs_setmode(int fd, int mode) {
#if defined(_WIN32)
  return fd < 0 ? mode : _setmode(fd, mode);
#else
  (void)fd;
  return mode;
#endif
}
