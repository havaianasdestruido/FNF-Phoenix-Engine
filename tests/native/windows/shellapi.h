#ifndef PHOENIX_TEST_SHELLAPI_H
#define PHOENIX_TEST_SHELLAPI_H
#include <windows.h>
#define NIM_ADD 0
#define NIM_MODIFY 1
#define NIM_DELETE 2
#define NIF_MESSAGE 1
#define NIF_ICON 2
#define NIF_TIP 4
#define NIF_INFO 16
#define NIIF_INFO 1
#define WM_APP 0x8000
#define IDI_APPLICATION 32512
#define MAKEINTRESOURCEW(x) ((LPCWSTR)(x))
struct NOTIFYICONDATAW {
  DWORD cbSize; HWND hWnd; UINT uID; UINT uFlags; UINT uCallbackMessage; HICON hIcon;
  WCHAR szTip[128]; DWORD dwState; DWORD dwStateMask; WCHAR szInfo[256]; WCHAR szInfoTitle[64]; DWORD dwInfoFlags;
};
extern int mockNotifyAction, mockNotifyResult;
extern NOTIFYICONDATAW mockNotifyData;
inline BOOL Shell_NotifyIconW(DWORD action, NOTIFYICONDATAW *data) { mockNotifyAction = (int)action; mockNotifyData = *data; return mockNotifyResult; }
inline HICON LoadIconW(HINSTANCE, LPCWSTR) { return reinterpret_cast<HICON>(1); }
#endif
