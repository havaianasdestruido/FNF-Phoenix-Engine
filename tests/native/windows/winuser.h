#ifndef PHOENIX_TEST_WINUSER_H
#define PHOENIX_TEST_WINUSER_H
/* Test double for <winuser.h>. The Win32 test double in windows.h already
 * declares every user32 symbol the GDI module uses (GetDC, GetDesktopWindow,
 * GetSystemMetrics, GetWindowRect, GetCursorPos, ReleaseDC, etc.), so this
 * header only exists to satisfy the #include <winuser.h> in phoenix_gdi.h
 * without pulling in the real Windows SDK. */
#include <windows.h>
#endif
