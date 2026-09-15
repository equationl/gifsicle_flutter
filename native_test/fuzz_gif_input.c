#include "gifsicle_bridge.h"
#include <stdint.h>
#include <stddef.h>
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t length) {
  if (length > 65536)
    return 0;
  /* A bounded-dimension fuzz campaign; separate corpus tests cover limit rejection. */
  unsigned sw = length >= 10 ? (unsigned)data[6] + ((unsigned)data[7] << 8) : 0;
  unsigned sh = length >= 10 ? (unsigned)data[8] + ((unsigned)data[9] << 8) : 0;
  if ((uint64_t)sw * sh > 65536)
    return 0;
  for (size_t i = 0; i + 9 < length; i++) {
    if (data[i] == 0x2c) {
      unsigned x = data[i + 1] + ((unsigned)data[i + 2] << 8),
               y = data[i + 3] + ((unsigned)data[i + 4] << 8);
      unsigned w = data[i + 5] + ((unsigned)data[i + 6] << 8),
               h = data[i + 7] + ((unsigned)data[i + 8] << 8);
      if (!w)
        w = sw;
      if (!h)
        h = sh;
      if ((uint64_t)(x + w) * (y + h) > 65536)
        return 0;
    }
  }
  const char *args[] = {"--careful", "-"};
  gs_execution_result *r = gs_execute(2, args, data, length, NULL);
  gs_execution_result_free(r);
  return 0;
}
