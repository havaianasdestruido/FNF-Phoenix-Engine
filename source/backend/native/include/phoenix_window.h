#ifndef PHOENIX_WINDOW_H
#define PHOENIX_WINDOW_H

/*
 * Native window helpers shared by the engine's Windows backends.
 * Keep helpers static: hxcpp includes native metadata in several translation
 * units. Never operate on a window merely because it has the SDL class name.
 */
#if defined(_WIN32)

/* hxcpp can include native metadata before its own target-architecture
 * defines. Seed the macro Windows headers expect so winnt.h does not emit
 * "No Target Architecture" when this header is seen first. */
#if !defined(_AMD64_) && !defined(_X86_) && !defined(_ARM_) && !defined(_ARM64_)
#if defined(_M_X64) || defined(__x86_64__)
#define _AMD64_
#elif defined(_M_IX86) || defined(__i386__)
#define _X86_
#elif defined(_M_ARM64) || defined(__aarch64__)
#define _ARM64_
#elif defined(_M_ARM) || defined(__arm__)
#define _ARM_
#endif
#endif

#include <windows.h>
#include <dwmapi.h>
#include <shellapi.h>
#if defined(_MSC_VER)
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#endif
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
  ULONG_PTR originalClassStyle;
  bool tracked;
  bool classStyleTracked;
  bool alpha;
  bool colorKey;
  bool clickThrough;
  BYTE opacity;
  COLORREF key;
};

static PHOENIX_WINDOW_UNUSED PhoenixWindowState &phoenixWindowState()
{
  static PhoenixWindowState state = {NULL, 0, 0, false, false, false, false, false, 255, 0};
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
    // SDL_app is a process-wide class. Keep its saved style across HWND
    // recreation so the new handle can still restore it on reset.
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

static PHOENIX_WINDOW_UNUSED bool phoenixWindowGetClassStyle(HWND window, ULONG_PTR &style)
{
  SetLastError(0);
  style = GetClassLongPtrW(window, GCL_STYLE);
  return style != 0 || GetLastError() == 0;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetClassStyle(HWND window, ULONG_PTR style)
{
  SetLastError(0);
  const ULONG_PTR previous = SetClassLongPtrW(window, GCL_STYLE, (LONG_PTR)style);
  return previous != 0 || GetLastError() == 0;
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
  ULONG_PTR classStyle = 0;
  bool classStyleChanged = false;
  if (layered)
  {
    /*
     * SDL registers SDL_app with CS_OWNDC. Microsoft explicitly documents
     * WS_EX_LAYERED as incompatible with CS_OWNDC and CS_CLASSDC:
     * https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-setwindowlonga
     *
     * SDL has already acquired and retained the window HDC by this point, so
     * clear only the incompatible class bits while layering is active. Every
     * other class bit is preserved and the original value is restored below
     * when the last layered effect is removed.
     */
    if (!phoenixWindowGetClassStyle(window, classStyle))
      return false;
    const ULONG_PTR compatible = classStyle & ~(ULONG_PTR)(CS_OWNDC | CS_CLASSDC);
    if (compatible != classStyle)
    {
      if (!state.classStyleTracked)
        state.originalClassStyle = classStyle;
      if (!phoenixWindowSetClassStyle(window, compatible))
      {
        state = previous;
        return false;
      }
      state.classStyleTracked = true;
      classStyleChanged = true;
    }
  }

  if (next != style && !phoenixWindowSetStyle(window, next))
  {
    if (classStyleChanged)
      phoenixWindowSetClassStyle(window, classStyle);
    state = previous;
    return false;
  }
  if (layered)
  {
    DWORD flags = (state.alpha || state.clickThrough) ? LWA_ALPHA : 0;
    if (state.colorKey)
      flags |= LWA_COLORKEY;
    if (!SetLayeredWindowAttributes(window, state.key, state.opacity, flags))
    {
      phoenixWindowSetStyle(window, style);
      if (classStyleChanged)
        phoenixWindowSetClassStyle(window, classStyle);
      state = previous;
      return false;
    }
  }
  else if (state.classStyleTracked)
  {
    // Layering has been removed; SDL can have its original class style back.
    if (!phoenixWindowSetClassStyle(window, state.originalClassStyle))
    {
      state.tracked = true;
      RedrawWindow(window, NULL, NULL,
        RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW);
      return false;
    }
    state.classStyleTracked = false;
  }
  state.tracked = true;

  // Microsoft's layered-window guide requires a real repaint after removing
  // WS_EX_LAYERED; invalidate both client and non-client areas immediately.
  RedrawWindow(window, NULL, NULL,
    RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW);
  return true;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetOpacity(double opacity)
{
  if (!phoenixWindowState().window)
    return false;
  if (!(opacity >= 0.0)) opacity = 0.0; // also handles NaN
  if (opacity > 1.0) opacity = 1.0;
  PhoenixWindowState &state = phoenixWindowState();
  const PhoenixWindowState previous = state;
  state.opacity = (BYTE)(opacity * 255.0 + 0.5);
  state.alpha = state.opacity != 255;
  if (phoenixWindowApplyTransparency()) return true;
  state = previous;
  return false;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetColorKey(COLORREF key, bool enabled)
{
  if (!phoenixWindowState().window)
    return false;
  PhoenixWindowState &state = phoenixWindowState();
  const PhoenixWindowState previous = state;
  state.key = key;
  state.colorKey = enabled;
  if (phoenixWindowApplyTransparency()) return true;
  state = previous;
  return false;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetClickThrough(bool enabled)
{
  if (!phoenixWindowState().window)
    return false;
  PhoenixWindowState &state = phoenixWindowState();
  const PhoenixWindowState previous = state;
  state.clickThrough = enabled;
  if (phoenixWindowApplyTransparency()) return true;
  state = previous;
  return false;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowResetTransparency()
{
  if (!phoenixWindowState().window)
    return false;
  PhoenixWindowState &state = phoenixWindowState();
  const PhoenixWindowState previous = state;
  state.alpha = state.colorKey = state.clickThrough = false;
  state.opacity = 255;
  state.key = 0;
  if (phoenixWindowApplyTransparency()) return true;
  state = previous;
  return false;
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

/**
 * Whether Windows apps use the light theme (Settings > Personalization >
 * Colors > "Choose your default app mode"). Ported from Troll Engine's
 * source/funkin/api/src/darkmode.cpp (isLightTheme):
 * https://github.com/troll-slaiyers/FNF-Troll-Engine
 * https://stackoverflow.com/questions/51334674/how-to-detect-windows-10-light-dark-mode-in-win32-application
 *
 * Returns true (the OS default) when the preference cannot be read, e.g. on
 * Windows versions that predate the setting, instead of throwing as the
 * original does.
 */
static PHOENIX_WINDOW_UNUSED bool phoenixWindowIsLightTheme()
{
  HKEY key = NULL;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", 0,
        KEY_QUERY_VALUE, &key) != ERROR_SUCCESS)
    return true;
  DWORD value = 1;
  DWORD type = 0;
  DWORD size = sizeof(value);
  const LONG status = RegQueryValueExW(key, L"AppsUseLightTheme", NULL, &type,
    reinterpret_cast<LPBYTE>(&value), &size);
  RegCloseKey(key);
  if (status != ERROR_SUCCESS || type != REG_DWORD || size != sizeof(value))
    return true;
  return value != 0;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetFrameColor(DWORD attribute, COLORREF color)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  if (attribute != 34 && attribute != 35 && attribute != 36)
    return false;
  return SUCCEEDED(DwmSetWindowAttribute(window, attribute, &color, sizeof(color)));
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetCloseEnabled(bool enabled)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  HMENU menu = GetSystemMenu(window, FALSE);
  if (menu == NULL)
    return false;
  const UINT flags = MF_BYCOMMAND | (enabled ? MF_ENABLED : MF_GRAYED);
  if (EnableMenuItem(menu, SC_CLOSE, flags) == -1)
    return false;
  DrawMenuBar(window);
  return true;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetBlur(bool enabled)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  DWM_BLURBEHIND blur = {};
  blur.dwFlags = DWM_BB_ENABLE;
  blur.fEnable = enabled ? TRUE : FALSE;
  blur.hRgnBlur = NULL;
  blur.fTransitionOnMaximized = FALSE;
  return SUCCEEDED(DwmEnableBlurBehindWindow(window, &blur));
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowSetSquareCorners(bool square)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  // DWMWA_WINDOW_CORNER_PREFERENCE = 33; DEFAULT = 1, DONOTROUND = 2.
  DWORD preference = square ? 2 : 1;
  return SUCCEEDED(DwmSetWindowAttribute(window, 33, &preference, sizeof(preference)));
}

static PHOENIX_WINDOW_UNUSED int phoenixWindowMessageBox(const char *message, const char *title, bool yesNo, bool error)
{
  std::vector<wchar_t> wideMessage, wideTitle;
  if (!phoenixWindowUtf8ToWide(message != NULL ? message : "", wideMessage)
      || !phoenixWindowUtf8ToWide(title != NULL ? title : "Phoenix Engine", wideTitle))
    return 0;
  HWND owner = phoenixWindowState().window;
  if (owner != NULL && !phoenixWindowIsGameWindow(owner))
    owner = NULL;
  UINT flags = yesNo ? (MB_YESNO | MB_ICONQUESTION) : (MB_OK | (error ? MB_ICONERROR : MB_ICONINFORMATION));
  return MessageBoxW(owner, &wideMessage[0], &wideTitle[0], flags);
}

/* One notification-area icon per game window; deleted on shutdown. */
struct PhoenixNotificationState { HWND owner; bool added; };
static PHOENIX_WINDOW_UNUSED PhoenixNotificationState &phoenixNotificationState()
{
  static PhoenixNotificationState state = {NULL, false};
  return state;
}
static PHOENIX_WINDOW_UNUSED void phoenixWindowCopyNotificationText(WCHAR *destination, size_t capacity, const std::vector<wchar_t> &source)
{
  size_t length = source.empty() ? 0 : source.size() - 1;
  if (length >= capacity)
    length = capacity - 1;
  // Do not split a UTF-16 surrogate pair at the shell's fixed buffer limit.
  if (length > 0 && length < source.size() - 1 && source[length - 1] >= 0xD800 && source[length - 1] <= 0xDBFF)
    --length;
  if (length > 0)
    memcpy(destination, &source[0], length * sizeof(WCHAR));
  destination[length] = 0;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowNotify(const char *title, const char *message)
{
  HWND window = phoenixWindowState().window;
  if (window == NULL || !phoenixWindowIsGameWindow(window))
    return false;
  std::vector<wchar_t> wideTitle, wideMessage;
  if (!phoenixWindowUtf8ToWide(title != NULL ? title : "", wideTitle)
      || !phoenixWindowUtf8ToWide(message != NULL ? message : "", wideMessage))
    return false;

  PhoenixNotificationState &icon = phoenixNotificationState();
  if (icon.added && icon.owner != window)
  {
    NOTIFYICONDATAW old = {};
    old.cbSize = sizeof(old);
    old.hWnd = icon.owner;
    old.uID = 1;
    Shell_NotifyIconW(NIM_DELETE, &old);
    icon.added = false;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = 1;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_INFO;
  data.uCallbackMessage = WM_APP + 1;
  data.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512));
  phoenixWindowCopyNotificationText(data.szTip, sizeof(data.szTip) / sizeof(data.szTip[0]), wideTitle);
  phoenixWindowCopyNotificationText(data.szInfoTitle, sizeof(data.szInfoTitle) / sizeof(data.szInfoTitle[0]), wideTitle);
  phoenixWindowCopyNotificationText(data.szInfo, sizeof(data.szInfo) / sizeof(data.szInfo[0]), wideMessage);
  data.dwInfoFlags = NIIF_INFO;
  const BOOL result = Shell_NotifyIconW(icon.added ? NIM_MODIFY : NIM_ADD, &data);
  if (result)
  {
    icon.added = true;
    icon.owner = window;
  }
  return result != FALSE;
}

static PHOENIX_WINDOW_UNUSED bool phoenixWindowRemoveNotification()
{
  PhoenixNotificationState &icon = phoenixNotificationState();
  if (!icon.added)
    return true;
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = icon.owner;
  data.uID = 1;
  if (!Shell_NotifyIconW(NIM_DELETE, &data))
    return false;
  icon.added = false;
  icon.owner = NULL;
  return true;
}

#endif
#endif
