#ifndef PHOENIX_TEST_XRANDR_H
#define PHOENIX_TEST_XRANDR_H
// Small XRandR test double; see ../Xlib.h.
#include <X11/Xlib.h>
struct XRRScreenConfiguration { short rate; };
extern int mockRandrAvailable;
extern int mockScreenInfoAvailable;
extern short mockRate;
extern int mockLiveConfigs;
extern int mockScreenInfoQueries;
inline int XRRQueryExtension(Display *, int *eventBase, int *errorBase) { *eventBase = 89; *errorBase = 147; return mockRandrAvailable; }
inline XRRScreenConfiguration *XRRGetScreenInfo(Display *, Window window)
{
  ++mockScreenInfoQueries;
  if (!mockScreenInfoAvailable || window != 42) return NULL;
  ++mockLiveConfigs;
  XRRScreenConfiguration *config = new XRRScreenConfiguration();
  config->rate = mockRate;
  return config;
}
inline short XRRConfigCurrentRate(XRRScreenConfiguration *config) { return config->rate; }
inline void XRRFreeScreenConfigInfo(XRRScreenConfiguration *config) { --mockLiveConfigs; delete config; }
#endif
