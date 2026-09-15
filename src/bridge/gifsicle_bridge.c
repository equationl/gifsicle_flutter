#include "gifsicle_bridge.h"
#include "gifsicle_context.h"
#include <limits.h>
#include <math.h>
#include "capabilities.inc"
#if defined(__ANDROID__)
#define GS_PLATFORM "android"
#elif defined(_WIN32)
#define GS_PLATFORM "windows"
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define GS_PLATFORM "ios"
#else
#define GS_PLATFORM "macos"
#endif
#else
#define GS_PLATFORM "unsupported"
#endif
uint32_t gs_bridge_abi_version(void) { return GS_BRIDGE_ABI_VERSION; }
const char *gs_gifsicle_version(void) { return "1.96"; }
const char *gs_capabilities_json(void) {
  return "{\"platform\":\"" GS_PLATFORM "\"," GS_CAPABILITIES_BODY;
}
static int capture(gs_io *f, uint8_t **p, size_t *n) {
  if (!f)
    return 0;
  *p = f->data;
  *n = f->length;
  f->data = NULL;
  f->owned = 0;
  return 1;
}
static gs_execution_result *execute_impl(int isolated, int32_t argc, const char *const *argv,
                                         const uint8_t *stdin_data, size_t stdin_length,
                                         const char *working_directory) {
  gs_execution_result *r = calloc(1, sizeof(*r));
  if (!r)
    return NULL;
  if (stdin_length > UINT32_MAX || argc < 0 || argc > 65535 || (argc && !argv) ||
      (stdin_length && !stdin_data)) {
    r->bridge_status = 1;
    return r;
  }
  char **args = calloc((size_t)argc + 2, sizeof(char *));
  if (!args) {
    r->bridge_status = 4;
    return r;
  }
  args[0] = "gifsicle";
  for (int i = 0; i < argc; i++) {
    if (!argv[i]) {
      r->bridge_status = 1;
      free(args);
      return r;
    }
    args[i + 1] = (char *)argv[i];
  }
  gs_io *out = NULL, *err = NULL;
  gs_lock();
  r->exit_code = gs_context_run(argc + 1, args, stdin_data, stdin_length, working_directory,
                                isolated, &out, &err, &r->bridge_status);
  if (!capture(out, &r->stdout_data, &r->stdout_length))
    r->bridge_status = 4;
  if (!capture(err, (uint8_t **)&r->stderr_data, &r->stderr_length))
    r->bridge_status = 4;
  gs_io_destroy(out);
  gs_io_destroy(err);
  gs_unlock();
  free(args);
  return r;
}
void gs_execution_result_free(gs_execution_result *r) {
  if (r) {
    free(r->stdout_data);
    free(r->stderr_data);
    free(r);
  }
}
void gs_result_free(gs_result *r) {
  if (r) {
    free(r->output_data);
    free(r->error_message);
    free(r->warnings);
    free(r);
  }
}
gs_result *gs_transform(const uint8_t *data, size_t length, const gs_options *o) {
  gs_result *r = calloc(1, sizeof(*r));
  if (!r)
    return NULL;
  if (!data || !length || !o) {
    r->status = 1;
    return r;
  }
  if (o->abi_version != 1 || o->struct_size != sizeof(*o)) {
    r->status = 9;
    return r;
  }
  if (o->optimization_level < 0 || o->optimization_level > 3 || o->lossy < -1 || o->lossy > 200 ||
      (o->colors != -1 && (o->colors < 2 || o->colors > 256)) || o->gamma_mode < 0 ||
      o->gamma_mode > 2 ||
      (o->gamma_mode == 2 && (!isfinite(o->gamma_value) || o->gamma_value <= 0)) ||
      o->resize_mode < 0 || o->resize_mode > 4 || o->interlace_mode < -1 || o->interlace_mode > 1 ||
      !isfinite(o->scale_x) || !isfinite(o->scale_y) || o->scale_x < 0 || o->scale_y < 0 ||
      ((o->scale_x > 0) != (o->scale_y > 0)) || (o->resize_mode && o->scale_x > 0) ||
      (o->resize_mode && (o->resize_width <= 0 || o->resize_height <= 0)) ||
      (o->crop_enabled &&
       (o->crop_x < 0 || o->crop_y < 0 || o->crop_width <= 0 || o->crop_height <= 0))) {
    r->status = 1;
    return r;
  }
  char buf[20][128];
  const char *args[20];
  int n = 0;
#define ADD(...)                                                                                   \
  do {                                                                                             \
    snprintf(buf[n], sizeof(buf[n]), __VA_ARGS__);                                                 \
    args[n] = buf[n];                                                                              \
    n++;                                                                                           \
  } while (0)
  ADD("--optimize=%d", o->optimization_level);
  if (o->lossy >= 0)
    ADD("--lossy=%d", o->lossy);
  if (o->colors >= 0)
    ADD("--colors=%d", o->colors);
  if (o->gamma_mode == 0)
    ADD("--gamma=srgb");
  else
    ADD("--gamma=%.17g", o->gamma_mode == 1 ? 1.0 : o->gamma_value);
  if (o->crop_enabled)
    ADD("--crop=%d,%d+%dx%d", o->crop_x, o->crop_y, o->crop_width, o->crop_height);
  if (o->resize_mode)
    ADD("--%s=%dx%d",
        o->resize_mode == 1   ? "resize"
        : o->resize_mode == 2 ? "resize-fit"
        : o->resize_mode == 3 ? "resize-touch"
                              : "resize",
        o->resize_width, o->resize_height);
  if (o->scale_x > 0)
    ADD("--scale=%.17gx%.17g", o->scale_x, o->scale_y);
  if (o->interlace_mode >= 0)
    ADD("--%sinterlace", o->interlace_mode ? "" : "no-");
  if (o->careful)
    ADD("--careful");
  if (o->remove_comments)
    ADD("--no-comments");
  ADD("-");
  gs_execution_result *e = gs_execute(n, args, data, length, NULL);
  if (!e) {
    r->status = 4;
    return r;
  }
  r->status = e->bridge_status ? e->bridge_status : e->exit_code ? 2 : 0;
  r->output_data = e->stdout_data;
  r->output_length = e->stdout_length;
  e->stdout_data = NULL;
  if (r->status) {
    r->error_message = e->stderr_data;
    r->error_message_length = e->stderr_length;
  } else {
    r->warnings = e->stderr_data;
    r->warnings_length = e->stderr_length;
  }
  e->stderr_data = NULL;
  gs_execution_result_free(e);
  return r;
}

gs_execution_result *gs_execute(int32_t argc, const char *const *argv, const uint8_t *data,
                                size_t length, const char *directory) {
  return execute_impl(0, argc, argv, data, length, directory);
}
gs_execution_result *gs_execute_isolated(int32_t argc, const char *const *argv, const uint8_t *data,
                                         size_t length, const char *directory) {
  return execute_impl(1, argc, argv, data, length, directory);
}
