#ifndef GS_PLATFORM_CONFIG_H
#define GS_PLATFORM_CONFIG_H
#if !defined(_WIN32) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <limits.h>
#include <math.h>
#define HAVE_CONFIG_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_INT64_T 1
#define HAVE_UINT64_T 1
#define HAVE_UINTPTR_T 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_TIME_H 1
#define HAVE_STRERROR 1
#define HAVE_STRTOUL 1
#define HAVE_SNPRINTF 1
#define HAVE_POW 1
#define HAVE_CBRTF 1
#define ENABLE_THREADS 0
#define HAVE_SIMD 0
#define STDC_HEADERS 1
#define VERSION "1.96"
#define PACKAGE "gifsicle"
#define PACKAGE_VERSION VERSION
#define PATHNAME_SEPARATOR '/'
#define SIZEOF_UNSIGNED_INT 4
#define SIZEOF_FLOAT 4
#if defined(_WIN32)
#include <io.h>
#include <fcntl.h>
#define SIZEOF_UNSIGNED_LONG 4
#define SIZEOF_VOID_P 8
#define isatty _isatty
#define fileno _fileno
#else
#include <unistd.h>
#define HAVE_UNISTD_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_TIME_H 1
#define SIZEOF_UNSIGNED_LONG __SIZEOF_LONG__
#define SIZEOF_VOID_P __SIZEOF_POINTER__
#endif
#define RANDOM gs_random
#define GIF_ALLOCATOR_DEFINED 1
#define Gif_Free free
_Static_assert(sizeof(unsigned int) == 4, "unsigned int width");
_Static_assert(sizeof(unsigned long) == SIZEOF_UNSIGNED_LONG, "long width");
_Static_assert(sizeof(void *) == SIZEOF_VOID_P, "pointer width");
_Static_assert(sizeof(uint32_t) == 4 && sizeof(uint64_t) == 8, "integer widths");
#endif
