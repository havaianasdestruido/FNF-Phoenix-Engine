#ifndef PHOENIX_TEST_XLIB_H
#define PHOENIX_TEST_XLIB_H
// Small Xlib test double for source/backend/native/src/phoenix_refresh_rate.cpp.
// The real headers are used instead when tests/native/run.sh finds them.
#include <cstddef>
struct Display { int screen; };
typedef unsigned long Window;
extern Display *mockDisplay; // NULL behaves like a session without an X server
extern int mockOpenDisplays;
extern int mockRootWindowQueries;
inline Display *XOpenDisplay(const char *) { if (mockDisplay != NULL) ++mockOpenDisplays; return mockDisplay; }
inline int XCloseDisplay(Display *) { --mockOpenDisplays; return 0; }
inline Window mockDefaultRootWindow(Display *) { ++mockRootWindowQueries; return 42; }
#define DefaultRootWindow(display) mockDefaultRootWindow(display)
#endif
