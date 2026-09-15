#ifndef GIFSICLE_BRIDGE_H
#define GIFSICLE_BRIDGE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#if defined(_WIN32)
#define GIFSICLE_FLUTTER_EXPORT __declspec(dllexport)
#else
#define GIFSICLE_FLUTTER_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif
#include <stddef.h>
#include <stdint.h>

#define GS_BRIDGE_ABI_VERSION 1

typedef struct gs_options {
  uint32_t abi_version;
  uint32_t struct_size;
  int32_t optimization_level;
  int32_t lossy;
  int32_t colors;
  int32_t gamma_mode;
  double gamma_value;
  int32_t resize_mode;
  int32_t resize_width;
  int32_t resize_height;
  double scale_x;
  double scale_y;
  int32_t crop_enabled;
  int32_t crop_x;
  int32_t crop_y;
  int32_t crop_width;
  int32_t crop_height;
  int32_t interlace_mode;
  int32_t careful;
  int32_t remove_comments;
} gs_options;

typedef struct gs_result {
  int32_t status;
  uint8_t *output_data;
  size_t output_length;
  char *error_message;
  size_t error_message_length;
  char *warnings;
  size_t warnings_length;
} gs_result;

typedef struct gs_execution_result {
  int32_t bridge_status;
  int32_t exit_code;
  uint8_t *stdout_data;
  size_t stdout_length;
  char *stderr_data;
  size_t stderr_length;
} gs_execution_result;
GIFSICLE_FLUTTER_EXPORT
uint32_t gs_bridge_abi_version(void);

GIFSICLE_FLUTTER_EXPORT
const char *gs_gifsicle_version(void);

GIFSICLE_FLUTTER_EXPORT
const char *gs_capabilities_json(void);

GIFSICLE_FLUTTER_EXPORT
gs_execution_result *gs_execute(int32_t argc, const char *const *argv, const uint8_t *stdin_data,
                                size_t stdin_length, const char *working_directory);

GIFSICLE_FLUTTER_EXPORT
gs_result *gs_transform(const uint8_t *input_data, size_t input_length, const gs_options *options);

GIFSICLE_FLUTTER_EXPORT
void gs_result_free(gs_result *result);

GIFSICLE_FLUTTER_EXPORT
void gs_execution_result_free(gs_execution_result *result);

GIFSICLE_FLUTTER_EXPORT
gs_execution_result *gs_execute_isolated(int32_t argc, const char *const *argv, const uint8_t *data,
                                         size_t length, const char *directory);
GIFSICLE_FLUTTER_EXPORT
int32_t gs_publish_file(const char *source, const char *target, int32_t overwrite);
#ifdef __cplusplus
}
#endif
#endif
