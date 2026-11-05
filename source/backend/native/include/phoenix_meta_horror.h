#ifndef PHOENIX_META_HORROR_H
#define PHOENIX_META_HORROR_H

/*
 * Native helpers for the 4th-wall-breaking ("META_HORROR") effects.
 *
 * Why this is a header and not `@:headerCode` inside MetaHorror.hx:
 * `MetaHorror` is an all-static class with no instance methods, so hxcpp never
 * emits the `MetaHorror.h` inclusion into the generated `MetaHorror.cpp`. A
 * `@:headerCode` block there would put the Win32/WASAPI declarations in the
 * header only, and every `@:functionCode` body would then compile against
 * undefined `IMMDeviceEnumerator`, `POINT`, `INPUT`, ... (the Windows CI build
 * failed exactly like that). `@:cppFileCode('#include "phoenix_meta_horror.h"')`
 * injects this header straight into the translation unit instead, which is how
 * every other native backend in the engine does it.
 *
 * Keep helpers static: hxcpp includes native metadata in several translation
 * units, so external linkage would break the link.
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

/* WASAPI headers ask for Vista+ symbols (CoInitializeEx/CoCreateInstance);
 * some toolchains default to a lower _WIN32_WINNT. */
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0600
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif

#include <windows.h>
#include <shellapi.h>
#include "phoenix_window.h"

#include <mmdeviceapi.h>
#include <endpointvolume.h>

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#if defined(_MSC_VER)
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
#endif

#if defined(__GNUC__) || defined(__clang__)
#define PHOENIX_META_UNUSED __attribute__((unused))
#else
#define PHOENIX_META_UNUSED
#endif

/* hxcpp-generated code and the engine's shared headers `#undef TRUE/FALSE`,
 * so the window-enumeration callbacks below must not rely on those macros. */
static const BOOL phoenixMetaTrue = 1;
static const BOOL phoenixMetaFalse = 0;

/* ------------------------------------------------------------------ */
/* UTF-8 <-> UTF-16                                                    */
/* ------------------------------------------------------------------ */

/* hxcpp Strings are UTF-8; the Win32 wide APIs want UTF-16. Converting here
 * keeps the Haxe snippets down to a plain `path.c_str()` call. */
static PHOENIX_META_UNUSED std::wstring phoenixMetaUtf8ToWide(const std::string &text)
{
  if (text.empty())
    return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, NULL, 0);
  if (length <= 0)
    return std::wstring();
  std::wstring wide((size_t)length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, &wide[0], length) != length)
    return std::wstring();
  // The converted string is NUL-terminated; drop the terminator from the size.
  wide.resize((size_t)length - 1);
  return wide;
}

static PHOENIX_META_UNUSED std::string phoenixMetaWideToUtf8(const std::wstring &text)
{
  if (text.empty())
    return std::string();
  const int length = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), -1, NULL, 0, NULL, NULL);
  if (length <= 0)
    return std::string();
  std::string narrow((size_t)length, '\0');
  if (WideCharToMultiByte(CP_UTF8, 0, text.c_str(), -1, &narrow[0], length, NULL, NULL) != length)
    return std::string();
  narrow.resize((size_t)length - 1);
  return narrow;
}

/* ------------------------------------------------------------------ */
/* Window titles                                                       */
/* ------------------------------------------------------------------ */

/* Title of the game window, so the enumeration callbacks can skip ourselves
 * and the shell. Set immediately before each EnumWindows() pass. */
static std::string phoenixMetaOwnWindowTitle;

static PHOENIX_META_UNUSED bool phoenixMetaIsIgnoredTitle(const char *title)
{
  const std::string value(title != NULL ? title : "");
  return value.empty() || value == phoenixMetaOwnWindowTitle || value == "Program Manager"
    || value == "Setup";
}

/* EnumWindows callback: hide every visible titled window except the game
 * itself and the shell, remembering titles for restoration. */
static BOOL CALLBACK phoenixMetaHideProc(HWND hwnd, LPARAM lparam)
{
  std::vector<std::string> *hidden = reinterpret_cast<std::vector<std::string> *>(lparam);
  char titleBuffer[512] = {0};
  int length = GetWindowTextA(hwnd, titleBuffer, 512);
  if (IsWindowVisible(hwnd) && length > 0 && !phoenixMetaIsIgnoredTitle(titleBuffer))
  {
    ShowWindow(hwnd, SW_HIDE);
    hidden->push_back(std::string(titleBuffer));
  }
  return phoenixMetaTrue;
}

/* EnumWindows callback: collect the titles of the other visible top-level
 * windows. Read-only: nothing is hidden, moved or activated. */
static BOOL CALLBACK phoenixMetaListProc(HWND hwnd, LPARAM lparam)
{
  std::vector<std::string> *titles = reinterpret_cast<std::vector<std::string> *>(lparam);
  char titleBuffer[512] = {0};
  int length = GetWindowTextA(hwnd, titleBuffer, 512);
  if (IsWindowVisible(hwnd) && length > 0 && !phoenixMetaIsIgnoredTitle(titleBuffer))
    titles->push_back(std::string(titleBuffer));
  return phoenixMetaTrue;
}

/* Both EnumWindows passes: list_ == true collects titles, false hides them. */
static PHOENIX_META_UNUSED std::vector<std::string> phoenixMetaEnumerateWindows(
  const std::string &ownTitle, bool list_)
{
  std::vector<std::string> titles;
  phoenixMetaOwnWindowTitle = ownTitle;
  WNDENUMPROC callback = list_ ? phoenixMetaListProc : phoenixMetaHideProc;
  EnumWindows(callback, reinterpret_cast<LPARAM>(&titles));
  phoenixMetaOwnWindowTitle.clear();
  return titles;
}

/* Re-shows windows hidden by a previous hide pass. Returns how many came
 * back. */
static PHOENIX_META_UNUSED int phoenixMetaRestoreWindows(const char *const *titles, int count)
{
  int restored = 0;
  for (int index = 0; index < count; index++)
  {
    HWND window = FindWindowA(NULL, titles[index]);
    if (window != NULL && ShowWindow(window, SW_SHOWNA))
      restored++;
  }
  return restored;
}

/* ------------------------------------------------------------------ */
/* System-wide audio (WASAPI)                                          */
/* ------------------------------------------------------------------ */

/* GUIDs are spelled out so no import library beyond ole32 is required. */
static const CLSID phoenixMetaClsidMMDeviceEnumerator = {
  0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};
static const IID phoenixMetaIidIMMDeviceEnumerator = {
  0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};
static const IID phoenixMetaIidIAudioEndpointVolume = {
  0x5CDF2C82, 0x841E, 0x4546, {0x97, 0x22, 0x0C, 0xF7, 0x40, 0x78, 0x22, 0x9A}};

/* Grabs the default output endpoint. COM is initialized process-wide and
 * intentionally left initialized (other engine systems use it too). */
static PHOENIX_META_UNUSED bool phoenixMetaAudioEndpoint(
  IMMDeviceEnumerator **enumerator, IMMDevice **device, IAudioEndpointVolume **endpoint)
{
  *enumerator = NULL;
  *device = NULL;
  *endpoint = NULL;
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  if (FAILED(CoCreateInstance(phoenixMetaClsidMMDeviceEnumerator, NULL, CLSCTX_ALL,
        phoenixMetaIidIMMDeviceEnumerator, (void **)enumerator)))
    return false;
  if (FAILED((*enumerator)->GetDefaultAudioEndpoint(eRender, eMultimedia, device)))
  {
    /* Release the enumerator on every failure path, otherwise a machine with
     * no output device would leak one COM object per volume/torrent call. */
    (*enumerator)->Release();
    *enumerator = NULL;
    return false;
  }
  if (FAILED((*device)->Activate(phoenixMetaIidIAudioEndpointVolume, CLSCTX_ALL, NULL,
        (void **)endpoint)))
  {
    (*device)->Release();
    *device = NULL;
    (*enumerator)->Release();
    *enumerator = NULL;
    return false;
  }
  return true;
}

/* Releases the three WASAPI objects returned by phoenixMetaAudioEndpoint. */
static PHOENIX_META_UNUSED void phoenixMetaReleaseAudio(
  IMMDeviceEnumerator *enumerator, IMMDevice *device, IAudioEndpointVolume *endpoint)
{
  if (endpoint != NULL) endpoint->Release();
  if (device != NULL) device->Release();
  if (enumerator != NULL) enumerator->Release();
}

static PHOENIX_META_UNUSED bool phoenixMetaSetMasterVolume(double volume)
{
  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioEndpointVolume *endpoint = NULL;
  if (!phoenixMetaAudioEndpoint(&enumerator, &device, &endpoint))
    return false;
  const bool ok = SUCCEEDED(endpoint->SetMasterVolumeLevelScalar((float)volume, NULL));
  phoenixMetaReleaseAudio(enumerator, device, endpoint);
  return ok;
}

static PHOENIX_META_UNUSED bool phoenixMetaSetMasterMute(bool mute)
{
  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioEndpointVolume *endpoint = NULL;
  if (!phoenixMetaAudioEndpoint(&enumerator, &device, &endpoint))
    return false;
  const bool ok = SUCCEEDED(endpoint->SetMute(mute ? 1 : 0, NULL));
  phoenixMetaReleaseAudio(enumerator, device, endpoint);
  return ok;
}

/* Current master volume as 0.0-1.0, or -1.0 when unavailable. */
static PHOENIX_META_UNUSED double phoenixMetaGetMasterVolume()
{
  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioEndpointVolume *endpoint = NULL;
  if (!phoenixMetaAudioEndpoint(&enumerator, &device, &endpoint))
    return -1.0;
  float level = -1.0f;
  endpoint->GetMasterVolumeLevelScalar(&level);
  phoenixMetaReleaseAudio(enumerator, device, endpoint);
  return (double)level;
}

static PHOENIX_META_UNUSED bool phoenixMetaGetMasterMute()
{
  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioEndpointVolume *endpoint = NULL;
  if (!phoenixMetaAudioEndpoint(&enumerator, &device, &endpoint))
    return false;
  BOOL muted = phoenixMetaFalse;
  endpoint->GetMute(&muted);
  phoenixMetaReleaseAudio(enumerator, device, endpoint);
  return muted != 0;
}

/* ------------------------------------------------------------------ */
/* Mouse & keyboard injection                                          */
/* ------------------------------------------------------------------ */

/* Moves the cursor by a relative offset (upstream `nircmd sendmouse move`). */
static PHOENIX_META_UNUSED bool phoenixMetaMoveMouse(int dx, int dy)
{
  POINT point;
  if (!GetCursorPos(&point))
    return false;
  return SetCursorPos(point.x + dx, point.y + dy) != 0;
}

/* Sends one virtual key. Walks the keyboard scan code instead of the VK
 * directly so the key also reaches DirectInput-only applications. */
static PHOENIX_META_UNUSED bool phoenixMetaSendVirtualKey(UINT virtualKey, bool keyUp)
{
  INPUT input;
  memset(&input, 0, sizeof(input));
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = (WORD)virtualKey;
  input.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : 0;
  return SendInput(1, &input, sizeof(INPUT)) == 1;
}

/* Types one Unicode character with KEYEVENTF_UNICODE, so any keyboard layout
 * and any script work without mapping characters to VK codes. */
static PHOENIX_META_UNUSED bool phoenixMetaSendUnicodeChar(unsigned int charCode)
{
  INPUT inputs[2];
  memset(inputs, 0, sizeof(inputs));
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
  inputs[0].ki.wScan = (WORD)charCode;
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
  inputs[1].ki.wScan = (WORD)charCode;
  return SendInput(2, inputs, sizeof(INPUT)) == 2;
}

/* ------------------------------------------------------------------ */
/* Files, wallpaper & the taskbar                                      */
/* ------------------------------------------------------------------ */

/* ShellExecuteW the path with the OS default application. SW_SHOWNORMAL (1)
 * is the success threshold; anything <= 32 is a documented failure code. */
static PHOENIX_META_UNUSED bool phoenixMetaOpenFile(const std::string &path, HWND owner)
{
  const std::wstring wide = phoenixMetaUtf8ToWide(path);
  if (wide.empty())
    return false;
  HINSTANCE result = ShellExecuteW(owner, L"open", wide.c_str(), NULL, NULL, SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(result) > 32;
}

static PHOENIX_META_UNUSED bool phoenixMetaSetWallpaper(const std::string &path)
{
  const std::wstring wide = phoenixMetaUtf8ToWide(path);
  if (wide.empty())
    return false;
  return SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, (void *)wide.c_str(),
    SPIF_UPDATEINIFILE | SPIF_SENDCHANGE) != 0;
}

/* Current wallpaper path as UTF-8, or an empty string when unavailable. */
static PHOENIX_META_UNUSED std::string phoenixMetaGetWallpaper()
{
  WCHAR buffer[1024] = {0};
  if (!SystemParametersInfoW(SPI_GETDESKWALLPAPER, 1024, buffer, 0))
    return std::string();
  return phoenixMetaWideToUtf8(std::wstring(buffer));
}

/* Hides the taskbar and reports whether it was visible before (so restore can
 * tell a real change from a no-op). */
static PHOENIX_META_UNUSED bool phoenixMetaHideTaskbar()
{
  HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
  if (taskbar == NULL)
    return true; /* pretend it was visible so restore is a harmless no-op */
  const BOOL wasVisible = IsWindowVisible(taskbar);
  ShowWindow(taskbar, SW_HIDE);
  return wasVisible != phoenixMetaFalse;
}

static PHOENIX_META_UNUSED void phoenixMetaRestoreTaskbar(bool wasVisible)
{
  if (!wasVisible)
    return;
  HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
  if (taskbar == NULL)
    return;
  ShowWindow(taskbar, SW_SHOWNOACTIVATE);
}

/* Strips WS_SYSMENU: the icon and the close/minimize/maximize menu. */
static PHOENIX_META_UNUSED bool phoenixMetaRemoveWindowIcon(HWND window)
{
  if (window == NULL)
    return false;
  SetWindowLongPtrW(window, GWL_STYLE, GetWindowLongPtrW(window, GWL_STYLE) & ~WS_SYSMENU);
  SetWindowPos(window, NULL, 0, 0, 0, 0,
    SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
  return true;
}

/* ------------------------------------------------------------------ */
/* Focus games                                                         */
/* ------------------------------------------------------------------ */

/* Seconds since the machine booted. */
static PHOENIX_META_UNUSED double phoenixMetaSystemUptime()
{
  return (double)GetTickCount64() / 1000.0;
}

/* HWND_TOPMOST / HWND_NOTOPMOST without touching position, size or focus. */
static PHOENIX_META_UNUSED bool phoenixMetaSetAlwaysOnTop(HWND window, bool top)
{
  if (window == NULL)
    return false;
  return SetWindowPos(window, top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER) != 0;
}

/* Flashes the taskbar button `count` times (1-10). */
static PHOENIX_META_UNUSED bool phoenixMetaFlashTaskbar(HWND window, int count)
{
  if (window == NULL)
    return false;
  FLASHWINFO info;
  memset(&info, 0, sizeof(info));
  info.cbSize = sizeof(FLASHWINFO);
  info.hwnd = window;
  info.dwFlags = FLASHW_TRAY;
  info.uCount = (UINT)(count > 0 ? count : 1);
  info.dwTimeout = 0;
  return FlashWindowEx(&info) != 0;
}

static PHOENIX_META_UNUSED void phoenixMetaStopTaskbarFlash(HWND window)
{
  if (window == NULL)
    return;
  FLASHWINFO info;
  memset(&info, 0, sizeof(info));
  info.cbSize = sizeof(FLASHWINFO);
  info.hwnd = window;
  info.dwFlags = FLASHW_STOP;
  FlashWindowEx(&info);
}

/* ------------------------------------------------------------------ */
/* Whole-desktop capture                                               */
/* ------------------------------------------------------------------ */

/*
 * Captures the virtual screen (every monitor, including a negative origin)
 * into a 24-bit BMP file.
 *
 * A BMP rather than a pixel buffer on purpose: hxcpp would have to marshal a
 * Haxe array element by element, which is several hundred megabytes of Haxe
 * heap for a 4K desktop. OpenFL can decode the BMP natively, so the caller
 * re-encodes it to PNG in Haxe and deletes this intermediate file.
 *
 * 24-bit BI_RGB, bottom-up rows (the DIB section's natural order) with the
 * usual 4-byte row padding; the alpha channel is dropped because a screen
 * capture's alpha is 0, which would read as fully transparent.
 */
static PHOENIX_META_UNUSED bool phoenixMetaCaptureDesktopToBmp(const std::string &path)
{
  const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (width <= 0 || height <= 0)
    return false;

  HDC screen = GetDC(NULL);
  if (screen == NULL)
    return false;

  BITMAPINFO info;
  memset(&info, 0, sizeof(info));
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;

  void *bits = NULL;
  HBITMAP dib = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits, NULL, 0);
  HDC memory = CreateCompatibleDC(screen);
  if (dib == NULL || memory == NULL || bits == NULL)
  {
    if (memory != NULL) DeleteDC(memory);
    if (dib != NULL) DeleteObject(dib);
    ReleaseDC(NULL, screen);
    return false;
  }

  HGDIOBJ previous = SelectObject(memory, dib);
  /* SRCCOPY | CAPTUREBLT also grabs layered windows (tooltips, overlays). */
  const BOOL copied = BitBlt(memory, 0, 0, width, height, screen, left, top, SRCCOPY | CAPTUREBLT);
  SelectObject(memory, previous);
  DeleteDC(memory);
  ReleaseDC(NULL, screen);

  if (!copied)
  {
    DeleteObject(dib);
    return false;
  }

  const int rowBytes = width * 3;
  const int padding = (4 - (rowBytes % 4)) % 4;

  const std::wstring wide = phoenixMetaUtf8ToWide(path);
  FILE *file = wide.empty() ? NULL : _wfopen(wide.c_str(), L"wb");
  if (file == NULL)
  {
    DeleteObject(dib);
    return false;
  }

  BITMAPFILEHEADER header;
  memset(&header, 0, sizeof(header));
  header.bfType = 0x4D42; /* "BM" */
  header.bfOffBits = (DWORD)(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER));
  header.bfSize = (DWORD)(header.bfOffBits + (DWORD)(rowBytes + padding) * (DWORD)height);

  BITMAPINFOHEADER pixelInfo;
  memset(&pixelInfo, 0, sizeof(pixelInfo));
  pixelInfo.biSize = sizeof(BITMAPINFOHEADER);
  pixelInfo.biWidth = width;
  pixelInfo.biHeight = height;
  pixelInfo.biPlanes = 1;
  pixelInfo.biBitCount = 24;
  pixelInfo.biCompression = BI_RGB;
  pixelInfo.biSizeImage = (DWORD)(rowBytes + padding) * (DWORD)height;

  bool ok = fwrite(&header, sizeof(header), 1, file) == 1
    && fwrite(&pixelInfo, sizeof(pixelInfo), 1, file) == 1;

  const unsigned char *source = (const unsigned char *)bits;
  const unsigned char pad[3] = {0, 0, 0};
  std::vector<unsigned char> row;
  if (ok)
    row.resize((size_t)rowBytes);

  for (int y = 0; ok && y < height; y++)
  {
    const unsigned char *pixel = source + (size_t)y * (size_t)width * 4;
    for (int x = 0; x < width; x++)
    {
      /* DIB pixels are BGRA; the BMP row wants BGR. */
      row[(size_t)x * 3] = pixel[(size_t)x * 4];
      row[(size_t)x * 3 + 1] = pixel[(size_t)x * 4 + 1];
      row[(size_t)x * 3 + 2] = pixel[(size_t)x * 4 + 2];
    }
    ok = fwrite(&row[0], 1, (size_t)rowBytes, file) == (size_t)rowBytes;
    if (ok && padding > 0)
      ok = fwrite(pad, 1, (size_t)padding, file) == (size_t)padding;
  }

  fclose(file);
  DeleteObject(dib);
  return ok;
}

#endif /* _WIN32 */

#endif /* PHOENIX_META_HORROR_H */
