#ifndef PHOENIX_TEST_DWMAPI_H
#define PHOENIX_TEST_DWMAPI_H
#include <windows.h>
#ifndef FAILED
#define FAILED(x) ((x) < 0)
#endif
#ifndef SUCCEEDED
#define SUCCEEDED(x) ((x) >= 0)
#endif
extern HRESULT mockDwmResult;
extern DWORD mockDwmAttribute, mockDwmValue;
extern int mockDwmCalls;
extern COLORREF mockDwmColor;
inline HRESULT DwmSetWindowAttribute(HWND, DWORD attribute, const void *value, DWORD) {
  mockDwmAttribute = attribute; mockDwmColor = *(const COLORREF *)value;
  if (attribute == 33) { mockDwmValue = *(const DWORD *)value; }
  else if (attribute == 20 || attribute == 19) { mockDwmValue = *(const BOOL *)value; }
  ++mockDwmCalls;
  if (attribute == 33 && mockDwmValue != 1 && mockDwmValue != 2) return (HRESULT)0x80070057;
  return attribute == 20 ? mockDwmResult : S_OK;
}
struct DWM_BLURBEHIND { DWORD dwFlags; BOOL fEnable; void *hRgnBlur; BOOL fTransitionOnMaximized; };
#define DWM_BB_ENABLE 1
extern HRESULT mockBlurResult;
extern BOOL mockBlurEnabled;
inline HRESULT DwmEnableBlurBehindWindow(HWND, const DWM_BLURBEHIND *blur) { mockBlurEnabled = blur->fEnable; return mockBlurResult; }
#endif
