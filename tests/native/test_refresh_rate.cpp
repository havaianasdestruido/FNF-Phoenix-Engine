// Behaviour of the Linux refresh rate query against the Xlib/XRandR test
// double in tests/native/x11. Built with phoenix_refresh_rate.cpp as a second
// translation unit, the same way hxcpp links it into the game.
#include "phoenix_refresh_rate.h"
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#include <cassert>
#include <iostream>

static Display display = {0};
Display *mockDisplay = &display;
int mockOpenDisplays = 0;
int mockRootWindowQueries = 0;
int mockRandrAvailable = 1;
int mockScreenInfoAvailable = 1;
short mockRate = 144;
int mockLiveConfigs = 0;
int mockScreenInfoQueries = 0;

// Every path must close the display and free the screen configuration.
static void assertReleased()
{
  assert(mockOpenDisplays == 0);
  assert(mockLiveConfigs == 0);
}

int main()
{
  assert(phoenixMonitorRefreshRate() == 144);
  assert(mockRootWindowQueries == 1 && mockScreenInfoQueries == 1);
  assertReleased();

  mockRate = 60;
  assert(phoenixMonitorRefreshRate() == 60);
  assertReleased();

  // No X server (Wayland-only or headless): report "unknown", touch nothing.
  mockDisplay = NULL;
  mockScreenInfoQueries = 0;
  assert(phoenixMonitorRefreshRate() == 0);
  assert(mockScreenInfoQueries == 0);
  assertReleased();
  mockDisplay = &display;

  // X server without the RandR extension.
  mockRandrAvailable = 0;
  assert(phoenixMonitorRefreshRate() == 0);
  assert(mockScreenInfoQueries == 0);
  assertReleased();
  mockRandrAvailable = 1;

  // RandR present but the screen configuration request fails.
  mockScreenInfoAvailable = 0;
  assert(phoenixMonitorRefreshRate() == 0);
  assertReleased();
  mockScreenInfoAvailable = 1;

  // A server that reports no rate must not leak a zero or negative value.
  mockRate = 0;
  assert(phoenixMonitorRefreshRate() == 0);
  mockRate = -1;
  assert(phoenixMonitorRefreshRate() == 0);
  assertReleased();

  mockRate = 240;
  assert(phoenixMonitorRefreshRate() == 240);
  assertReleased();

  std::cout << "refresh rate native tests passed\n";
}
