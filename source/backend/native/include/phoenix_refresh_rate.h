#ifndef PHOENIX_REFRESH_RATE_H
#define PHOENIX_REFRESH_RATE_H

/*
 * Monitor refresh rate query for Linux desktops (X11/XWayland), ported from
 * Troll Engine's source/funkin/api/src/refreshrate.cpp:
 * https://github.com/troll-slaiyers/FNF-Troll-Engine
 *
 * Unlike the other phoenix_*.h helpers this one is NOT header-only. Xlib.h
 * defines macros such as None, Bool, Status, Success and Always that break
 * hxcpp-generated C++, so the X11 includes stay inside
 * ../src/phoenix_refresh_rate.cpp and this header only declares the function.
 */
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the refresh rate of the default X screen in Hz, or zero if it cannot
 * be determined (no reachable X server, no RandR extension, or a target other
 * than desktop Linux). Opens and closes its own display connection, so it
 * never touches SDL's.
 */
int phoenixMonitorRefreshRate(void);

#ifdef __cplusplus
}
#endif

#endif
