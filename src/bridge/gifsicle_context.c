#include "gifsicle_context.h"
#include <errno.h>
#if defined(_WIN32)
#include <windows.h>
static SRWLOCK mutex = SRWLOCK_INIT;
void gs_lock(void) { AcquireSRWLockExclusive(&mutex); }
void gs_unlock(void) { ReleaseSRWLockExclusive(&mutex); }
#else
#include <pthread.h>
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
void gs_lock(void) { pthread_mutex_lock(&mutex); }
void gs_unlock(void) { pthread_mutex_unlock(&mutex); }
#endif
/* All request memory and FILEs are owned here, including fatal parser paths.
   0.1 prototype uses setjmp; replacing this is an explicit 1.0 release gate. */
typedef union allocation allocation;
union allocation {
#if defined(_WIN32)
  /* MSVC's C headers do not provide max_align_t. Match the Windows heap
     alignment so advancing past this header preserves malloc alignment. */
  _Alignas(MEMORY_ALLOCATION_ALIGNMENT) unsigned char alignment;
#else
  max_align_t alignment;
#endif
  struct {
    allocation *prev, *next;
  } links;
};
#if defined(_WIN32)
_Static_assert(_Alignof(allocation) >= MEMORY_ALLOCATION_ALIGNMENT,
               "allocation header must preserve Windows heap alignment");
_Static_assert(sizeof(allocation) % MEMORY_ALLOCATION_ALIGNMENT == 0,
               "allocation payload offset must preserve Windows heap alignment");
#endif
#ifdef GS_TESTING
static void check_allocation_alignment(const allocation *a) {
  assert((uintptr_t)a % _Alignof(allocation) == 0);
  assert((uintptr_t)(a + 1) % _Alignof(allocation) == 0);
}
#endif

typedef struct saved {
  struct saved *next;
  void *address;
  size_t size;
  unsigned char bytes[];
} saved;
typedef struct opened {
  struct opened *next;
  gs_io *file;
} opened;
typedef struct context {
  jmp_buf jump;
  allocation *allocations;
  saved *states;
  opened *files;
  gs_io *streams[3];
  const char *directory;
  int status, code, isolated, failing;
  uint32_t random;
} context;
static context *current;
_Noreturn void gs_exit(int code) {
  current->code = code;
  longjmp(current->jump, 1);
}
_Noreturn void gs_fail(int status, const char *message) {
  current->status = status;
  if (current->failing)
    gs_exit(1);
  current->failing = 1;
  if (current->streams[2])
    gs_fwrite(message, 1, strlen(message), current->streams[2]);
  gs_exit(1);
}
#ifdef GS_TESTING
static long fail_after = -1;
void gs_test_fail_alloc_after(long n) { fail_after = n; }
static void inject_allocation_failure(void) {
  if (fail_after == 0)
    gs_fail(4, "injected allocation failure");
  if (fail_after > 0)
    --fail_after;
}
#else
static void inject_allocation_failure(void) {}
#endif
void *gs_alloc(size_t n) {
  inject_allocation_failure();
  if (n > SIZE_MAX - sizeof(allocation))
    gs_fail(4, "allocation overflow");
  allocation *a = malloc(sizeof(allocation) + (n ? n : 1));
  if (!a)
    gs_fail(4, "out of memory");
  a->links.prev = NULL;
  a->links.next = current->allocations;
  if (current->allocations)
    current->allocations->links.prev = a;
  current->allocations = a;
#ifdef GS_TESTING
  check_allocation_alignment(a);
#endif
  return a + 1;
}
void gs_free(void *p) {
  if (!p)
    return;
  allocation *a = (allocation *)p - 1;
  if (a->links.prev)
    a->links.prev->links.next = a->links.next;
  else
    current->allocations = a->links.next;
  if (a->links.next)
    a->links.next->links.prev = a->links.prev;
  free(a);
}
void *gs_realloc(void *p, size_t n) {
  if (!p)
    return gs_alloc(n);
  if (!n) {
    gs_free(p);
    return NULL;
  }
  if (n > SIZE_MAX - sizeof(allocation))
    gs_fail(4, "allocation overflow");
  allocation *a = (allocation *)p - 1;
  inject_allocation_failure();
  allocation *b = realloc(a, sizeof(allocation) + n);
  if (!b)
    gs_fail(4, "out of memory");
  if (b->links.prev)
    b->links.prev->links.next = b;
  else
    current->allocations = b;
  if (b->links.next)
    b->links.next->links.prev = b;
#ifdef GS_TESTING
  check_allocation_alignment(b);
#endif
  return b + 1;
}
void *gs_calloc(size_t n, size_t s) {
  if (s && n > SIZE_MAX / s)
    gs_fail(4, "allocation overflow");
  void *p = gs_alloc(n * s);
  memset(p, 0, n * s);
  return p;
}
void gs_state(void *p, size_t n) {
  for (saved *s = current->states; s; s = s->next)
    if (s->address == p)
      return;
  saved *s = malloc(sizeof(saved) + n);
  if (!s)
    gs_fail(4, "out of memory recording native state");
  s->address = p;
  s->size = n;
  memcpy(s->bytes, p, n);
  s->next = current->states;
  current->states = s;
}
gs_io *gs_stream(int index) { return current->streams[index]; }
FILE *gs_fs_fopen(const char *, const char *);
gs_io *gs_fopen(const char *path, const char *mode) {
  if (current->isolated) {
    if (!path[0] || strchr(path, '/') || strchr(path, '\\') || strchr(path, ':') ||
        !strcmp(path, ".") || !strcmp(path, ".."))
      gs_fail(11, "path escapes isolated workspace");
  }
  char *resolved = NULL;
  if (current->directory && path[0] != '/' && path[0] != '\\' && !(path[0] && path[1] == ':')) {
    size_t n = strlen(current->directory) + strlen(path) + 2;
    resolved = gs_alloc(n);
    snprintf(resolved, n, "%s/%s", current->directory, path);
    path = resolved;
  }
  FILE *f = gs_fs_fopen(path, mode);
  gs_free(resolved);
  if (f) {
    opened *o = malloc(sizeof(opened));
    if (!o) {
      fclose(f);
      gs_fail(4, "out of memory tracking file");
    }
    gs_io *io = calloc(1, sizeof(*io));
    if (!io) {
      free(o);
      fclose(f);
      gs_fail(4, "out of memory tracking stream");
    }
    io->disk = f;
    io->writable = strchr(mode, 'w') || strchr(mode, 'a') || strchr(mode, '+');
    o->file = io;
    o->next = current->files;
    current->files = o;
    return io;
  }
  return NULL;
}
int gs_fclose(gs_io *f) {
  for (int i = 0; i < 3; i++)
    if (f == current->streams[i])
      return gs_fflush(f);
  opened **o = &current->files;
  while (*o && (*o)->file != f)
    o = &(*o)->next;
  if (*o) {
    opened *old = *o;
    *o = old->next;
    free(old);
  }
  int r = gs_io_close(f);
  if (r)
    current->status = 6;
  return r;
}
int gs_printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int r = gs_vfprintf(gs_stream(1), fmt, ap);
  va_end(ap);
  return r;
}
int gs_puts(const char *s) {
  int r = gs_fputs(s, gs_stream(1));
  gs_putc('\n', gs_stream(1));
  return r;
}
int gs_putchar(int c) { return gs_putc(c, gs_stream(1)); }
long gs_random(void) {
  current->random = current->random * 1664525u + 1013904223u;
  return current->random & 0x7fffffff;
}
#define STATE_MODULES(X)                                                                           \
  X(clp)                                                                                           \
  X(fmalloc)                                                                                       \
  X(giffunc) X(gifread) X(gifunopt) X(gifwrite) X(kcolor) X(merge) X(optimize) X(quantize)         \
      X(support) X(xform) X(gifsicle)
#define DECLARE(n) void gs_state_##n(void);
STATE_MODULES(DECLARE)
int gs_cli_main(int argc, char **argv);
int gs_context_run(int argc, char **argv, const uint8_t *data, size_t length, const char *directory,
                   int isolated, gs_io **out, gs_io **err, int *status) {
  context *c = calloc(1, sizeof(*c));
  if (!c) {
    *status = 4;
    return 1;
  }
  current = c;
  c->directory = directory;
  c->isolated = isolated;
  c->random = 1;
  if (setjmp(c->jump) == 0) {
    c->streams[0] = gs_io_memory(data, length, 0);
    c->streams[1] = gs_io_memory(NULL, 0, 1);
    c->streams[2] = gs_io_memory(NULL, 0, 1);
#define SAVE(n) gs_state_##n();
    STATE_MODULES(SAVE)
    c->code = gs_cli_main(argc, argv);
  }
  while (c->files) {
    opened *o = c->files;
    c->files = o->next;
    if (gs_io_close(o->file))
      c->status = 6;
    free(o);
  }
  while (c->states) {
    saved *s = c->states;
    c->states = s->next;
    memcpy(s->address, s->bytes, s->size);
    free(s);
  }
  while (c->allocations)
    gs_free(c->allocations + 1);
  gs_io_destroy(c->streams[0]);
  *out = c->streams[1];
  *err = c->streams[2];
  *status = c->status;
  int code = c->code;
  free(c);
  current = NULL;
  return code;
}
