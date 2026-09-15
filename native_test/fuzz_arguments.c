#include "gifsicle_bridge.h"
#include <stdint.h>
#include <stddef.h>
#include <string.h>
static const uint8_t gif[] = {71, 73,  70,  56,  57, 97,  1, 0, 1,  0,  128, 0, 0,  0, 0,
                              0,  255, 255, 255, 33, 249, 4, 1, 10, 0,  0,   0, 44, 0, 0,
                              0,  0,   1,   0,   1,  0,   0, 2, 2,  68, 1,   0, 59};
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t length) {
  if (length > 128)
    return 0;
  char token[160] = "--dither=";
  memcpy(token + 9, data, length);
  token[9 + length] = 0;
  const char *args[] = {token, "--colors=2", "-"};
  gs_execution_result *r = gs_execute(3, args, gif, sizeof(gif), NULL);
  gs_execution_result_free(r);
  return 0;
}
