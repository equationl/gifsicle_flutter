#ifndef GS_IO_H
#define GS_IO_H
#include "gifsicle_platform_config.h"
#include <stdarg.h>
typedef struct gs_io {
  FILE *disk;
  unsigned char *data;
  size_t length, capacity, position;
  int owned, writable;
} gs_io;
gs_io *gs_io_memory(const uint8_t *data, size_t length, int writable);
void gs_io_destroy(gs_io *io);
int gs_io_close(gs_io *io);
size_t gs_fread(void *p, size_t size, size_t count, gs_io *io);
size_t gs_fwrite(const void *p, size_t size, size_t count, gs_io *io);
int gs_getc(gs_io *io);
int gs_ungetc(int c, gs_io *io);
int gs_putc(int c, gs_io *io);
int gs_fputs(const char *s, gs_io *io);
char *gs_fgets(char *s, int n, gs_io *io);
int gs_vfprintf(gs_io *io, const char *fmt, va_list ap);
int gs_fprintf(gs_io *io, const char *fmt, ...);
int gs_fflush(gs_io *io);
int gs_fileno(gs_io *io);
int gs_setmode(int fd, int mode);
#endif
