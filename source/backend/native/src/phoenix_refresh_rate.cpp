/*
 * Ported from Troll Engine's source/funkin/api/src/refreshrate.cpp:
 * https://github.com/troll-slaiyers/FNF-Troll-Engine
 * Original approach:
 * https://stackoverflow.com/questions/17797636/c-linux-get-the-refresh-rate-of-a-monitor
 *
 * Changes from the original: a missing X server or RandR extension returns
 * zero instead of dereferencing a null display, the screen configuration is
 * freed, the default screen is used instead of screen 0, and other targets
 * return zero instead of throwing across the hxcpp boundary.
 */
#include "phoenix_refresh_rate.h"

#if defined(__linux__) && !defined(__ANDROID__)

#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

int phoenixMonitorRefreshRate(void)
{
  int rate = 0;
  int eventBase = 0;
  int errorBase = 0;
  XRRScreenConfiguration *config = NULL;
  Display *display = XOpenDisplay(NULL);
  if (display == NULL)
    return 0; /* Wayland-only session, headless machine or bad DISPLAY. */

  if (XRRQueryExtension(display, &eventBase, &errorBase))
    config = XRRGetScreenInfo(display, DefaultRootWindow(display));
  if (config != NULL)
  {
    rate = (int)XRRConfigCurrentRate(config);
    XRRFreeScreenConfigInfo(config);
  }
  XCloseDisplay(display);
  return rate > 0 ? rate : 0;
}

#else

int phoenixMonitorRefreshRate(void)
{
  return 0; /* Not desktop Linux: callers fall back to Lime's display mode. */
}

#endif
