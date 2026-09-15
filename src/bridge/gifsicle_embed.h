/* Included after system headers in each vendored translation unit. */
#include "gifsicle_context.h"
#undef stdin
#undef stdout
#undef stderr
#define stdin gs_stream(0)
#define stdout gs_stream(1)
#define stderr gs_stream(2)
#define malloc gs_alloc
#define calloc gs_calloc
#define realloc gs_realloc
#define free gs_free
#define fopen gs_fopen
#define fclose gs_fclose
#define printf gs_printf
#define puts gs_puts
#define putchar gs_putchar
#define exit gs_exit
#define abort() gs_fail(7, "native invariant failed")
#undef assert
#define assert(x) ((x) ? (void)0 : gs_fail(7, "native invariant failed: " #x))

#define FILE gs_io
#define fread gs_fread
#define fwrite gs_fwrite
#define fprintf gs_fprintf
#define vfprintf gs_vfprintf
#define fputs gs_fputs
#define fputc gs_putc
#define fgets gs_fgets
#define fflush gs_fflush
#undef getc
#undef putc
#define getc gs_getc
#define putc gs_putc
#define ungetc gs_ungetc
#undef fileno
#define fileno gs_fileno
#define _fileno gs_fileno

#define _setmode gs_setmode
/* Streams are private memory/files, never the host's terminal. */
#undef isatty
#define isatty(fd) 0
