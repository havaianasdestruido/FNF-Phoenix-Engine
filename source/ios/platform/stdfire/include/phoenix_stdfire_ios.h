#ifndef PHOENIX_STDFIRE_IOS_H
#define PHOENIX_STDFIRE_IOS_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* UTF-8 input is copied before work is queued to UIKit's main thread. */
bool phoenixStdFireSetTitle(const char *title);
bool phoenixStdFireShowToast(const char *message);

#ifdef __cplusplus
}
#endif

#endif
