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

#endif
#endif
