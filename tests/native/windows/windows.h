#ifndef PHOENIX_TEST_WINDOWS_H
#define PHOENIX_TEST_WINDOWS_H
// Small Win32 test double; the real header is cross-compiled separately.
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>
typedef void *HWND;
typedef void *HMENU;
typedef void *HICON;
typedef void *HINSTANCE;
typedef unsigned int DWORD;
typedef long LONG;
typedef long long LONG_PTR;
typedef long long INT_PTR;
typedef unsigned long long UINT_PTR;
typedef unsigned long long ULONG_PTR;
typedef unsigned int UINT;
typedef int BOOL;
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef wchar_t WCHAR;
typedef const WCHAR *LPCWSTR;
typedef int HRESULT;
struct CLSID { DWORD data1; WORD data2; WORD data3; BYTE data4[8]; };
typedef CLSID IID;
#define eRender 0
#define eMultimedia 1
typedef DWORD COLORREF;
typedef long long LPARAM;
typedef ULONG_PTR WPARAM;
struct POINT { LONG x, y; };
typedef unsigned long long ULONGLONG;
typedef unsigned short WORD;
typedef void *HDC;
typedef void *HBITMAP;
typedef void *HGDIOBJ;
struct BITMAPINFOHEADER {
  DWORD biSize; int biWidth; int biHeight; WORD biPlanes; WORD biBitCount;
  DWORD biCompression; DWORD biSizeImage; DWORD biXPelsPerMeter;
  DWORD biYPelsPerMeter; DWORD biClrUsed; DWORD biClrImportant;
};
struct BITMAPINFO { BITMAPINFOHEADER bmiHeader; };
#pragma pack(push, 2)
struct BITMAPFILEHEADER { WORD bfType; DWORD bfSize; WORD bfReserved1; WORD bfReserved2; DWORD bfOffBits; };
#pragma pack(pop)
static_assert(sizeof(BITMAPFILEHEADER) == 14, "BITMAPFILEHEADER is a packed 14-byte struct");
inline int WideCharToMultiByte(UINT, DWORD, const WCHAR *text, int count, char *out, int cap, const char *, BOOL *)
{
  if (text == NULL || cap == 0) return count;
  int written = 0;
  for (int i = 0; text[i] != 0 && written + 1 < cap; i++)
    out[written++] = (char)(text[i] < 128 ? text[i] : '?');
  out[written] = 0;
  return written + 1;
}
/* The real SDK declares _wfopen in <wchar.h>. The mock defines a stub so the
 * META_HORROR capture helper compiles (and can be run) on any host. */
inline FILE *_wfopen(const WCHAR *, const WCHAR *) { return fopen("/dev/null", "wb"); }
struct RECT { LONG left, top, right, bottom; };
#ifndef CALLBACK
#define CALLBACK
#endif
typedef BOOL (*WNDENUMPROC)(HWND, LPARAM);
#define TRUE 1
#define FALSE 0
#define NULL_WINDOW ((HWND)0)
#define CP_UTF8 65001
#define MB_ERR_INVALID_CHARS 8
#define GA_ROOT 2
#define GWL_EXSTYLE (-20)
#define GWL_STYLE (-16)
#define GCL_STYLE (-26)
#define WS_EX_LAYERED 0x80000
#define WS_EX_TRANSPARENT 0x20
#define WS_SYSMENU 0x80000
#define CS_OWNDC 0x0020
#define CS_CLASSDC 0x0040
#define CS_BYTEALIGNCLIENT 0x1000
#define LWA_COLORKEY 1
#define LWA_ALPHA 2
#define SC_CLOSE 0xF060
#define MF_BYCOMMAND 0
#define MF_ENABLED 0
#define MF_GRAYED 1
#define SWP_NOSIZE 1
#define SWP_NOMOVE 2
#define SWP_NOZORDER 4
#define SWP_NOACTIVATE 16
#define SWP_FRAMECHANGED 32
#define RDW_INVALIDATE 1
#define RDW_ERASE 4
#define RDW_FRAME 0x400
#define RDW_ALLCHILDREN 0x80
#define RDW_UPDATENOW 256
#define MB_OK 0
#define MB_YESNO 4
#define MB_ICONINFORMATION 64
#define MB_ICONQUESTION 32
#define MB_ICONERROR 16
#define IDOK 1
#define IDYES 6
#define IDNO 7
#define S_OK 0
#define S_FALSE 1
#ifndef FAILED
#define FAILED(hr) (((HRESULT)(hr)) < 0)
#endif
#ifndef SUCCEEDED
#define SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)
#endif
#define CLSCTX_ALL 23
#define COINIT_APARTMENTTHREADED 2
#define SPI_GETDESKWALLPAPER 0x0073
#define SPI_SETDESKWALLPAPER 0x0014
#define SPIF_UPDATEINIFILE 1
#define SPIF_SENDCHANGE 2
#define SM_XVIRTUALSCREEN 76
#define SM_YVIRTUALSCREEN 77
#define SM_CXVIRTUALSCREEN 78
#define SM_CYVIRTUALSCREEN 79
#define BI_RGB 0
#define DIB_RGB_COLORS 0
#define SRCCOPY 0x00CC0020
#define CAPTUREBLT 0x40000000
#define SW_HIDE 0
#define SW_SHOWNOACTIVATE 4
#define SW_SHOWNA 8
#define SW_SHOWNORMAL 1
#define INPUT_KEYBOARD 1
#define KEYEVENTF_KEYUP 2
#define KEYEVENTF_UNICODE 4
#define FLASHW_STOP 0
#define FLASHW_TRAY 2
#define HWND_TOPMOST ((HWND)-1)
#define HWND_NOTOPMOST ((HWND)-2)
#define SWP_NOOWNERZORDER 0x200
typedef struct tagINPUT {
  DWORD type;
  struct { WORD wVk; WORD wScan; DWORD dwFlags; DWORD time; ULONG_PTR dwExtraInfo; } ki;
} INPUT;
struct FLASHWINFO {
  UINT cbSize; HWND hwnd; DWORD dwFlags; UINT uCount; DWORD dwTimeout;
};
#define RGB(r,g,b) ((COLORREF)((r) | ((g)<<8) | ((b)<<16)))
struct MockWindow { HWND handle; DWORD pid; std::string className; std::wstring title; LONG_PTR exStyle; bool alive; ULONG_PTR classStyle; };
extern std::vector<MockWindow> mockWindows;
extern DWORD mockProcess;
extern HWND mockActive, mockForeground;
extern int mockStyleFail;
extern int mockClassStyleFail;
extern DWORD mockLastError;
extern UINT mockRedrawFlags;
inline MockWindow *mockWindow(HWND h) { for (auto &w : mockWindows) if (w.handle == h) return &w; return NULL; }
inline BOOL IsWindow(HWND h) { auto w = mockWindow(h); return w && w->alive; }
inline HWND GetAncestor(HWND h, UINT) { return h; }
inline DWORD GetCurrentProcessId() { return mockProcess; }
inline DWORD GetWindowThreadProcessId(HWND h, DWORD *p) { auto w = mockWindow(h); *p = w ? w->pid : 0; return 1; }
inline int GetClassNameA(HWND h, char *out, int cap) { auto w = mockWindow(h); if (!w) return 0; std::strncpy(out, w->className.c_str(), cap - 1); return (int)w->className.size(); }
inline HWND GetActiveWindow() { return mockActive; }
inline HWND GetForegroundWindow() { return mockForeground; }
inline HWND FindWindowA(const char *cls, const char *) { for (auto &w : mockWindows) if (w.alive && w.className == cls) return w.handle; return NULL; }
inline HWND FindWindowExA(HWND, HWND after, const char *cls, const char *) { bool seen = after == NULL; for (auto &w : mockWindows) { if (w.handle == after) { seen = true; continue; } if (seen && w.alive && w.className == cls) return w.handle; } return NULL; }
inline int GetWindowTextLengthW(HWND h) { auto w = mockWindow(h); return w ? (int)w->title.size() : 0; }
inline int GetWindowTextW(HWND h, WCHAR *out, int cap) { auto w = mockWindow(h); if (!w) return 0; int n = (int)w->title.size(); if (n >= cap) n = cap - 1; for (int i = 0; i < n; ++i) out[i] = w->title[i]; out[n] = 0; return n; }
inline int MultiByteToWideChar(UINT, DWORD, const char *text, int, WCHAR *out, int cap) {
  /* Called twice by phoenixMetaUtf8ToWide: once with cap == 0 (size query). */
  std::vector<WCHAR> decoded;
  for (const unsigned char *p = reinterpret_cast<const unsigned char *>(text); *p;) {
    unsigned int c = *p++; int extra = 0;
    if (c >= 0xF0) { c &= 7; extra = 3; } else if (c >= 0xE0) { c &= 15; extra = 2; } else if (c >= 0xC0) { c &= 31; extra = 1; }
    while (extra-- > 0 && *p) c = (c << 6) | (*p++ & 63);
    decoded.push_back((WCHAR)c);
  }
  if (cap == 0) return (int)decoded.size() + 1;
  int n = (int)decoded.size(); if (n >= cap) return 0;
  for (int i = 0; i < n; ++i) { out[i] = decoded[i]; } out[n] = 0; return n + 1;
}
inline LONG_PTR GetWindowLongPtrW(HWND h, int) { auto w = mockWindow(h); return w ? w->exStyle : 0; }
inline LONG_PTR SetWindowLongPtrW(HWND h, int, LONG_PTR value) {
  auto w = mockWindow(h);
  if (!w || mockStyleFail || ((value & WS_EX_LAYERED) && (w->classStyle & (CS_OWNDC | CS_CLASSDC)))) {
    // SetWindowLong documents WS_EX_LAYERED as incompatible with these class styles.
    mockLastError = 5;
    return 0;
  }
  LONG_PTR old = w->exStyle;
  w->exStyle = value;
  mockLastError = 0;
  return old;
}
inline ULONG_PTR GetClassLongPtrW(HWND h, int) {
  auto w = mockWindow(h);
  if (!w || mockClassStyleFail) { mockLastError = 5; return 0; }
  mockLastError = 0;
  return w->classStyle;
}
inline ULONG_PTR SetClassLongPtrW(HWND h, int, LONG_PTR value) {
  auto w = mockWindow(h);
  if (!w || mockClassStyleFail) { mockLastError = 5; return 0; }
  ULONG_PTR old = w->classStyle;
  w->classStyle = static_cast<ULONG_PTR>(value);
  mockLastError = 0;
  return old;
}
inline BOOL SetWindowPos(HWND, HWND, int, int, int, int, UINT) { return TRUE; }
inline BOOL RedrawWindow(HWND, const RECT *, void *, UINT flags) { mockRedrawFlags = flags; return TRUE; }
extern DWORD mockLayerFlags, mockLayerKey;
extern BYTE mockLayerAlpha;
extern int mockLayerFail;
inline BOOL SetLayeredWindowAttributes(HWND, COLORREF key, BYTE alpha, DWORD flags) { if (mockLayerFail) return FALSE; mockLayerKey = key; mockLayerAlpha = alpha; mockLayerFlags = flags; return TRUE; }
extern HMENU mockMenu;
extern DWORD mockMenuFlags;
extern int mockMenuResult;
inline HMENU GetSystemMenu(HWND, BOOL) { return mockMenu; }
inline int EnableMenuItem(HMENU, UINT, UINT flags) { mockMenuFlags = flags; return mockMenuResult; }
inline BOOL DrawMenuBar(HWND) { return TRUE; }
extern int mockMessageResult;
extern UINT mockMessageFlags;
extern std::wstring mockMessageText, mockMessageTitle;
extern HWND mockMessageOwner;
inline int MessageBoxW(HWND owner, const WCHAR *message, const WCHAR *title, UINT flags) {
  mockMessageOwner = owner; mockMessageText = message; mockMessageTitle = title; mockMessageFlags = flags; return mockMessageResult;
}
inline void SetLastError(DWORD e) { mockLastError = e; }
inline DWORD GetLastError() { return mockLastError; }

// --- Registry stubs used by phoenixWindowIsLightTheme ------------------------
typedef void *HKEY;
typedef BYTE *LPBYTE;
#define HKEY_CURRENT_USER ((HKEY)(ULONG_PTR)0x80000001)
#define KEY_QUERY_VALUE 1
#define REG_SZ 1
#define REG_DWORD 4
#define ERROR_SUCCESS 0
#define ERROR_FILE_NOT_FOUND 2
extern LONG mockRegOpenResult, mockRegQueryResult;
extern DWORD mockRegType, mockRegValue, mockRegSize;
extern int mockRegOpenKeys;
extern std::wstring mockRegPath, mockRegName;
inline LONG RegOpenKeyExW(HKEY, const WCHAR *path, DWORD, DWORD, HKEY *out) {
  mockRegPath = path;
  if (mockRegOpenResult != ERROR_SUCCESS) return mockRegOpenResult;
  ++mockRegOpenKeys; *out = reinterpret_cast<HKEY>(1); return ERROR_SUCCESS;
}
inline LONG RegQueryValueExW(HKEY, const WCHAR *name, DWORD *, DWORD *type, LPBYTE data, DWORD *size) {
  mockRegName = name;
  if (mockRegQueryResult != ERROR_SUCCESS) return mockRegQueryResult;
  *type = mockRegType;
  if (mockRegSize <= *size) std::memcpy(data, &mockRegValue, mockRegSize);
  *size = mockRegSize;
  return ERROR_SUCCESS;
}
inline LONG RegCloseKey(HKEY) { --mockRegOpenKeys; return ERROR_SUCCESS; }

// --- Stubs used by the META_HORROR helpers (source/backend/native/include) ---
struct IUnknown { virtual unsigned long Release() { return 0; } };
struct IMMDevice : IUnknown {
  virtual HRESULT Activate(const IID &, DWORD, void *, void **out) { *out = NULL; return S_OK; }
};
struct IMMDeviceEnumerator : IUnknown {
  virtual HRESULT GetDefaultAudioEndpoint(DWORD, DWORD, IMMDevice **out) { *out = NULL; return S_OK; }
};
struct IAudioEndpointVolume : IUnknown {
  virtual HRESULT SetMasterVolumeLevelScalar(float, const void *) { return S_OK; }
  virtual HRESULT GetMasterVolumeLevelScalar(float *level) { *level = 0.5f; return S_OK; }
  virtual HRESULT SetMute(BOOL, const void *) { return S_OK; }
  virtual HRESULT GetMute(BOOL *muted) { *muted = FALSE; return S_OK; }
};

extern int mockCaptureResult;
extern std::string mockWallpaper;
extern UINT mockWindowCount;
inline int GetWindowTextA(HWND, char *out, int cap) { if (out && cap > 0) out[0] = 0; return 0; }
inline BOOL EnumWindows(BOOL (*callback)(HWND, LPARAM), LPARAM lparam) { (void)callback; (void)lparam; return TRUE; }
inline BOOL ShowWindow(HWND, int) { return TRUE; }
inline BOOL IsWindowVisible(HWND) { return TRUE; }
inline HWND FindWindowW(const WCHAR *, const WCHAR *) { return NULL; }
inline BOOL SystemParametersInfoW(UINT, UINT, void *data, UINT) {
  if (data != NULL) static_cast<WCHAR *>(data)[0] = 0;
  return TRUE;
}
inline ULONGLONG GetTickCount64() { return 1000; }
inline BOOL FlashWindowEx(FLASHWINFO *) { return TRUE; }
inline BOOL GetCursorPos(POINT *point) { if (point) { point->x = 0; point->y = 0; } return TRUE; }
inline BOOL SetCursorPos(int, int) { return TRUE; }
inline UINT SendInput(UINT count, INPUT *, int) { return count; }
inline HRESULT CoInitializeEx(void *, DWORD) { return S_OK; }
inline HRESULT CoCreateInstance(const CLSID &, void *, DWORD, const IID &, void **out) {
  // Behave like a box with no audio endpoint: the helper must bail out
  // instead of dereferencing a null enumerator.
  *out = NULL; return (HRESULT)-1;
}
inline int GetSystemMetrics(int) { return 0; }
inline HDC GetDC(HWND) { return NULL; }
inline HBITMAP CreateDIBSection(HDC, BITMAPINFO *, UINT, void **bits, void *, DWORD) {
  (void)bits; return NULL;
}
inline HDC CreateCompatibleDC(HDC) { return NULL; }
inline HGDIOBJ SelectObject(HDC, HGDIOBJ) { return NULL; }
inline BOOL BitBlt(HDC, int, int, int, int, HDC, int, int, DWORD) { return TRUE; }
inline BOOL DeleteDC(HDC) { return TRUE; }
inline BOOL DeleteObject(HBITMAP) { return TRUE; }
inline int ReleaseDC(HWND, HDC) { return 1; }
inline HINSTANCE ShellExecuteW(HWND, const WCHAR *, const WCHAR *, const WCHAR *, const WCHAR *, int) {
  return reinterpret_cast<HINSTANCE>(42);
}
#include <cstdio>
#endif
