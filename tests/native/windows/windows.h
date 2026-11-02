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
typedef unsigned long DWORD;
typedef long LONG;
typedef long long LONG_PTR;
typedef unsigned long ULONG_PTR;
typedef unsigned int UINT;
typedef int BOOL;
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef wchar_t WCHAR;
typedef const WCHAR *LPCWSTR;
typedef int HRESULT;
typedef DWORD COLORREF;
typedef long long LPARAM;
typedef ULONG_PTR WPARAM;
struct POINT { LONG x, y; };
struct RECT { LONG left, top, right, bottom; };
#define TRUE 1
#define FALSE 0
#define NULL_WINDOW ((HWND)0)
#define CP_UTF8 65001
#define MB_ERR_INVALID_CHARS 8
#define GA_ROOT 2
#define GWL_EXSTYLE (-20)
#define GWL_STYLE (-16)
#define WS_EX_LAYERED 0x80000
#define WS_EX_TRANSPARENT 0x20
#define WS_SYSMENU 0x80000
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
#define RGB(r,g,b) ((COLORREF)((r) | ((g)<<8) | ((b)<<16)))
struct MockWindow { HWND handle; DWORD pid; std::string className; std::wstring title; LONG_PTR exStyle; bool alive; };
extern std::vector<MockWindow> mockWindows;
extern DWORD mockProcess;
extern HWND mockActive, mockForeground;
extern int mockStyleFail;
extern DWORD mockLastError;
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
inline LONG_PTR SetWindowLongPtrW(HWND h, int, LONG_PTR value) { auto w = mockWindow(h); if (!w || mockStyleFail) { mockLastError = 5; return 0; } LONG_PTR old = w->exStyle; w->exStyle = value; mockLastError = 0; return old; }
inline BOOL SetWindowPos(HWND, HWND, int, int, int, int, UINT) { return TRUE; }
inline BOOL RedrawWindow(HWND, const RECT *, void *, UINT) { return TRUE; }
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
#endif
