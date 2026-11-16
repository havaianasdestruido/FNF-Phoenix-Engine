/* Intercept SDL's modal call in the headless Lime integration test. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int SDL_ShowSimpleMessageBox(uint32_t flags, const char *title, const char *message, void *window)
{
  (void)flags;
  const char *path = getenv("PHOENIX_TEST_LIME_ALERT_LOG");
  if (path == NULL || title == NULL || message == NULL || window == NULL)
    return -1;
  FILE *file = fopen(path, "wb");
  if (file == NULL)
    return -1;
  fputs(title, file);
  fputc('\n', file);
  fputs(message, file);
  return fclose(file) == 0 ? 0 : -1;
}
