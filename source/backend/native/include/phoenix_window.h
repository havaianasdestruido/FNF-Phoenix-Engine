#ifndef PHOENIX_WINDOW_H
#define PHOENIX_WINDOW_H

/*
 * Native window helpers shared by the engine's Windows backends.
 * Keep helpers static: hxcpp includes native metadata in several translation
 * units. Never operate on a window merely because it has the SDL class name.
 */
#if defined(_WIN32)

#include <windows.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <string>
#include <vector>

#if defined(__GNUC__) || defined(__clang__)
#define PHOENIX_WINDOW_UNUSED __attribute__((unused))
#else
#define PHOENIX_WINDOW_UNUSED
#endif

static PHOENIX_WINDOW_UNUSED bool phoenixWindowUtf8ToWide(const char *text, std::vector<wchar_t> &out)
{
  out.clear();
  if (text == NULL)
    return false;
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, NULL, 0);
  if (length <= 0)
    return false;
  out.resize(static_cast<size_t>(length));
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, &out[0], length) == length;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowIsGameWindow(HWND window)
{
  if (window == NULL || !IsWindow(window) || GetAncestor(window, GA_ROOT) != window)
    return false;
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  if (process != GetCurrentProcessId())
    return false;
  char className[32] = {0};
  return GetClassNameA(window, className, sizeof(className)) != 0 && std::string(className) == "SDL_app";
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowTitleMatches(HWND window, const char *title)
{
  if (title == NULL || title[0] == '\0')
    return true;
  std::vector<wchar_t> expected;
  if (!phoenixWindowUtf8ToWide(title, expected))
    return false;
  const int length = GetWindowTextLengthW(window);
  if (length < 0 || static_cast<size_t>(length) + 1 != expected.size())
    return false;
  std::vector<wchar_t> actual(expected.size());
  return GetWindowTextW(window, &actual[0], static_cast<int>(actual.size())) == length
    && std::wstring(&actual[0]) == std::wstring(&expected[0]);
}

/**
 * Find this process's Lime/SDL top-level window, not another application's.
 * An explicit UTF-8 Lime title disambiguates multiple windows in this process.
 * Without a title, an ambiguous match fails instead of guessing. The cache is
 * revalidated because recreating a frame can invalidate an HWND.
 */
static PHOENIX_WINDOW_UNUSED HWND phoenixWindowFind(const char *title = NULL)
{
  static HWND cached = NULL;
  if (phoenixWindowIsGameWindow(cached) && phoenixWindowTitleMatches(cached, title))
    return cached;
  cached = NULL;

  const HWND candidates[] = {GetActiveWindow(), GetForegroundWindow()};
  for (size_t index = 0; index < sizeof(candidates) / sizeof(candidates[0]); ++index)
  {
    HWND window = candidates[index];
    if (phoenixWindowIsGameWindow(window) && phoenixWindowTitleMatches(window, title))
    {
      cached = window;
      return window;
    }
  }

  HWND found = NULL;
  for (HWND window = FindWindowA("SDL_app", NULL); window != NULL;
       window = FindWindowExA(NULL, window, "SDL_app", NULL))
  {
    if (!phoenixWindowIsGameWindow(window) || !phoenixWindowTitleMatches(window, title))
      continue;
    if (found != NULL && (title == NULL || title[0] == '\0'))
      return NULL;
    found = window;
  }
  cached = found;
  return found;
}


/* Layered attributes are a single native state, not independent API calls. */
struct PhoenixWindowState
{
  HWND window;
  LONG_PTR originalStyle;
  bool tracked;
  bool alpha;
  bool colorKey;
  bool clickThrough;
  BYTE opacity;
  COLORREF key;
};

static PHOENIX_WINDOW_UNUSED PhoenixWindowState &phoenixWindowState()
{
  static PhoenixWindowState state = {NULL, 0, false, false, false, false, 255, 0};
  return state;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSelect(const char *title)
{
  HWND window = phoenixWindowFind(title);
  PhoenixWindowState &state = phoenixWindowState();
  if (window != state.window)
  {
    state.window = window;
    state.tracked = false;
    state.alpha = state.colorKey = state.clickThrough = false;
    state.opacity = 255;
    state.key = 0;
  }
  return window != NULL;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetStyle(HWND window, LONG_PTR style)
{
  SetLastError(0);
  LONG_PTR previous = SetWindowLongPtrW(window, GWL_EXSTYLE, style);
  if (previous == 0 && GetLastError() != 0)
    return false;
  SetWindowPos(window, NULL, 0, 0, 0, 0,
    SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  return true;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowApplyTransparency()
{
  PhoenixWindowState &state = phoenixWindowState();
  HWND window = state.window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  const LONG_PTR style = GetWindowLongPtrW(window, GWL_EXSTYLE);
  if (!state.tracked)
    state.originalStyle = style;
  const bool layered = state.alpha || state.colorKey || state.clickThrough;
  LONG_PTR next = style & ~(LONG_PTR)(WS_EX_LAYERED | WS_EX_TRANSPARENT);
  if (layered)
    next |= WS_EX_LAYERED;
  if (state.clickThrough)
    next |= WS_EX_TRANSPARENT;

  PhoenixWindowState previous = state;
  if (next != style && !phoenixWindowSetStyle(window, next))
    return false;
  if (layered)
  {
    DWORD flags = (state.alpha || state.clickThrough) ? LWA_ALPHA : 0;
    if (state.colorKey)
      flags |= LWA_COLORKEY;
    if (!SetLayeredWindowAttributes(window, state.key, state.opacity, flags))
    {
      phoenixWindowSetStyle(window, style);
      state = previous;
      return false;
    }
  }
  state.tracked = true;
  RedrawWindow(window, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW);
  return true;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetOpacity(double opacity)
{
  if (!phoenixWindowState().window)
    return false;
  if (!(opacity >= 0.0)) opacity = 0.0; // also handles NaN
  if (opacity > 1.0) opacity = 1.0;
  PhoenixWindowState &state = phoenixWindowState();
  state.opacity = (BYTE)(opacity * 255.0 + 0.5);
  state.alpha = state.opacity != 255;
  return phoenixWindowApplyTransparency();
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetColorKey(COLORREF key, bool enabled)
{
  if (!phoenixWindowState().window)
    return false;
  PhoenixWindowState &state = phoenixWindowState();
  state.key = key;
  state.colorKey = enabled;
  return phoenixWindowApplyTransparency();
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetClickThrough(bool enabled)
{
  if (!phoenixWindowState().window)
    return false;
  phoenixWindowState().clickThrough = enabled;
  return phoenixWindowApplyTransparency();
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowResetTransparency()
{
  if (!phoenixWindowState().window)
    return false;
  PhoenixWindowState &state = phoenixWindowState();
  state.alpha = state.colorKey = state.clickThrough = false;
  state.opacity = 255;
  state.key = 0;
  return phoenixWindowApplyTransparency();
}

/* SDK-compatible DWM attribute numbers (Windows 10 1809+ / Windows 11). */
#define PHOENIX_DWM_DARK_MODE 20
#define PHOENIX_DWM_DARK_MODE_LEGACY 19

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetDarkMode(bool enabled)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  BOOL value = enabled ? TRUE : FALSE;
  HRESULT result = DwmSetWindowAttribute(window, PHOENIX_DWM_DARK_MODE, &value, sizeof(value));
  if (FAILED(result))
    result = DwmSetWindowAttribute(window, PHOENIX_DWM_DARK_MODE_LEGACY, &value, sizeof(value));
  return SUCCEEDED(result);
}

#endif
#endif
