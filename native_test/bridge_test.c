#include "gifsicle_bridge.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#if !defined(_WIN32)
#include <pthread.h>
#endif
static const unsigned char gif[] = {71, 73,  70,  56,  57, 97,  1, 0, 1,  0,  128, 0, 0,  0, 0,
                                    0,  255, 255, 255, 33, 249, 4, 1, 10, 0,  0,   0, 44, 0, 0,
                                    0,  0,   1,   0,   1,  0,   0, 2, 2,  68, 1,   0, 59};
static void *exercise(void *unused) {
  (void)unused;
  for (int i = 0; i < 110; i++) {
    const char *args[] = {"--optimize=3", i % 2 ? "--gamma=1" : "--gamma=srgb", "-"};
    gs_execution_result *r = gs_execute(3, args, gif, sizeof(gif), NULL);
    if (r && (r->bridge_status || r->exit_code))
      fprintf(stderr, "%s", r->stderr_data ? r->stderr_data : "");
    assert(r && !r->bridge_status && !r->exit_code && r->stdout_length > 6);
    assert(!memcmp(r->stdout_data, "GIF", 3));
    gs_execution_result_free(r);
    const char *bad[] = {"--bad-option"};
    r = gs_execute(1, bad, NULL, 0, NULL);
    assert(r && !r->bridge_status && r->exit_code);
    gs_execution_result_free(r);
  }
  return NULL;
}
#ifdef GS_TESTING
void gs_test_fail_alloc_after(long n);
#endif
int main(void) {
#ifdef GS_TESTING
  for (long n = 0; n < 180; n++) {
    gs_test_fail_alloc_after(n);
    const char *a[] = {"-O3", "-"};
    gs_execution_result *r = gs_execute(2, a, gif, sizeof(gif), NULL);
    assert(r && (r->bridge_status == 4 || (!r->bridge_status && !r->exit_code)));
    gs_execution_result_free(r);
    gs_test_fail_alloc_after(-1);
  }
#endif

  assert(gs_bridge_abi_version() == 1);
  exercise(NULL);
#if !defined(_WIN32)
  pthread_t a, b;
  pthread_create(&a, NULL, exercise, NULL);
  pthread_create(&b, NULL, exercise, NULL);
  pthread_join(a, NULL);
  pthread_join(b, NULL);
#endif
  const char *invalid_cases[][4] = {{"--app-extension", "A", "body", "-"},
                                    {"--extension", "", "body", "-"},
                                    {"--gamma=nan", "--colors=2", "-", NULL},
                                    {"--scale=nan", "-", NULL, NULL}};
  for (int i = 0; i < 4; i++) {
    int n = 0;
    while (n < 4 && invalid_cases[i][n])
      n++;
    gs_execution_result *r = gs_execute(n, invalid_cases[i], gif, sizeof(gif), NULL);
    assert(r && (r->bridge_status || r->exit_code));
    gs_execution_result_free(r);
  }
  const char *dither[] = {"--dither=ordered,1,2,3,4,5,6", "-"};
  gs_execution_result *bad_dither = gs_execute(2, dither, gif, sizeof(gif), NULL);
  assert(bad_dither && !bad_dither->bridge_status && bad_dither->exit_code);
  gs_execution_result_free(bad_dither);
  const char *help[] = {"--help"};
  gs_execution_result *r = gs_execute(1, help, NULL, 0, NULL);
  assert(r && !r->bridge_status && !r->exit_code && r->stdout_length > 100);
  gs_execution_result_free(r);
  const char *external[] = {"--transform-c=echo bad"};
  r = gs_execute(1, external, NULL, 0, NULL);
  assert(r && r->bridge_status == 10);
  gs_execution_result_free(r);
  const char *stdinarg[] = {"-"};
  r = gs_execute(1, stdinarg, (const uint8_t *)"broken", 6, NULL);
  assert(r && r->exit_code);
  gs_execution_result_free(r);
  gs_execution_result_free(NULL);
  gs_result_free(NULL);
  puts("native bridge: repeated transforms, errors, gamma state, mutex and help passed");
}
