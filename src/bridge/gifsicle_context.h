#ifndef GS_CONTEXT_H
#define GS_CONTEXT_H
#include "gifsicle_platform_config.h"
#include <setjmp.h>
#include "gifsicle_io.h"
#include <stdarg.h>
void *gs_alloc(size_t n);
void *gs_realloc(void *p, size_t n);
void *gs_calloc(size_t n, size_t s);
void gs_free(void *p);
_Noreturn void gs_exit(int code);
_Noreturn void gs_fail(int status, const char *message);
gs_io *gs_stream(int index);
gs_io *gs_fopen(const char *path, const char *mode);
int gs_fclose(gs_io *f);
int gs_printf(const char *fmt, ...);
int gs_puts(const char *s);
int gs_putchar(int c);
void gs_state(void *p, size_t n);
long gs_random(void);
void gs_lock(void);
void gs_unlock(void);
int gs_context_run(int argc, char **argv, const uint8_t *data, size_t length, const char *directory,
                   int isolated, gs_io **out, gs_io **err, int *status);
#endif
