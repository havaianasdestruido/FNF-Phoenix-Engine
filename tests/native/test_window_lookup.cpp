#include "phoenix_window.h"
#include <cassert>
#include <iostream>

std::vector<MockWindow> mockWindows;
DWORD mockProcess = 10;
HWND mockActive = NULL, mockForeground = NULL;
int mockStyleFail = 0;
int mockClassStyleFail = 0;
DWORD mockLastError = 0;
UINT mockRedrawFlags = 0;
DWORD mockLayerFlags = 0, mockLayerKey = 0;
BYTE mockLayerAlpha = 255;
int mockLayerFail = 0;
HRESULT mockDwmResult = S_OK;
DWORD mockDwmAttribute = 0, mockDwmValue = 0;
int mockDwmCalls = 0;
COLORREF mockDwmColor = 0;
HRESULT mockBlurResult = S_OK;
BOOL mockBlurEnabled = 0;
HMENU mockMenu = reinterpret_cast<HMENU>(100);
DWORD mockMenuFlags = 0;
int mockMenuResult = 0;
int mockMessageResult = IDYES;
UINT mockMessageFlags = 0;
std::wstring mockMessageText, mockMessageTitle;
HWND mockMessageOwner = NULL;
int mockNotifyAction = -1, mockNotifyResult = 1;
NOTIFYICONDATAW mockNotifyData = {};

static HWND handle(size_t n) { return reinterpret_cast<HWND>(n + 1); }
static void reset()
{
  mockWindows.clear();
  mockActive = mockForeground = NULL;
  mockStyleFail = mockClassStyleFail = mockLayerFail = 0;
  mockRedrawFlags = 0;
  // This is the class style used by Phoenix's pinned SDL for SDL_app.
  const ULONG_PTR sdlClassStyle = CS_BYTEALIGNCLIENT | CS_OWNDC;
  mockWindows.push_back({handle(0), 10, "SDL_app", L"Phoenix", 0, true, sdlClassStyle});
  mockWindows.push_back({handle(1), 99, "SDL_app", L"Another game", 0, true, sdlClassStyle});
}
int main()
{
  reset();
  mockForeground = handle(1);
  assert(phoenixWindowFind("Phoenix") == handle(0));
  assert(phoenixWindowFind("Missing") == NULL);
  mockActive = handle(0);
  assert(phoenixWindowFind(NULL) == handle(0));
  mockActive = NULL;
  mockWindows[0].alive = false;
  assert(phoenixWindowFind(NULL) == NULL); // invalidate the cache
  mockWindows[0].alive = true;
  mockWindows.push_back({handle(2), 10, "SDL_app", L"Second window", 0, true, CS_BYTEALIGNCLIENT | CS_OWNDC});
  assert(phoenixWindowFind(NULL) == NULL); // two process-owned SDL windows: ambiguous
  mockWindows[0].title = L"Jogo \u2014 Phoenix";
  assert(phoenixWindowFind("Jogo \xe2\x80\x94 Phoenix") == handle(0));
  mockWindows[0].alive = false;
  assert(phoenixWindowFind("Jogo \xe2\x80\x94 Phoenix") == NULL);
  reset();
  mockWindows[0].className = "NotSDL";
  assert(phoenixWindowFind("Phoenix") == NULL);
  reset();
  assert(phoenixWindowSelect("Phoenix"));
  const ULONG_PTR sdlClassStyle = CS_BYTEALIGNCLIENT | CS_OWNDC;
  mockWindows[0].exStyle = 0x100;
  assert(phoenixWindowSetOpacity(0.5));
  assert(mockWindows[0].classStyle == CS_BYTEALIGNCLIENT);
  assert(mockWindows[0].exStyle == (0x100 | WS_EX_LAYERED));
  assert(phoenixWindowSetColorKey(RGB(1, 2, 3), true));
  assert(mockLayerFlags == (LWA_ALPHA | LWA_COLORKEY));
  assert(mockLayerAlpha == 128 && mockLayerKey == RGB(1, 2, 3));
  assert(phoenixWindowSetClickThrough(true));
  assert(mockWindows[0].exStyle == (0x100 | WS_EX_LAYERED | WS_EX_TRANSPARENT));
  assert(phoenixWindowSetOpacity(1.0));
  assert(mockLayerFlags == (LWA_ALPHA | LWA_COLORKEY)); // click-through needs alpha
  assert(mockLayerAlpha == 255);
  assert(phoenixWindowResetTransparency());
  assert(mockWindows[0].exStyle == 0x100);
  assert(mockWindows[0].classStyle == sdlClassStyle);
  const UINT requiredRepaint = RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN;
  assert((mockRedrawFlags & requiredRepaint) == requiredRepaint);

  // A failed layered-attribute request must also undo the temporary class style.
  mockLayerFail = 1;
  assert(!phoenixWindowSetColorKey(RGB(1, 2, 3), true));
  mockLayerFail = 0;
  assert(mockWindows[0].exStyle == 0x100);
  assert(mockWindows[0].classStyle == sdlClassStyle);
  assert(phoenixWindowResetTransparency());

  // Likewise, a rejected window-style change must not leave the class altered.
  mockStyleFail = 1;
  assert(!phoenixWindowSetOpacity(0.5));
  mockStyleFail = 0;
  assert(mockWindows[0].classStyle == sdlClassStyle);
  assert(phoenixWindowResetTransparency());

  // Failure to change the class must stop before touching the window style.
  mockClassStyleFail = 1;
  assert(!phoenixWindowSetOpacity(0.5));
  mockClassStyleFail = 0;
  assert(mockWindows[0].exStyle == 0x100);
  assert(mockWindows[0].classStyle == sdlClassStyle);
  assert(phoenixWindowResetTransparency());

  assert(phoenixWindowSetOpacity(2.0));
  assert(phoenixWindowSetOpacity(-1.0));
  assert(mockLayerAlpha == 0);
  mockStyleFail = 1;
  assert(!phoenixWindowResetTransparency());
  mockStyleFail = 0;
  assert(phoenixWindowResetTransparency());
  assert(mockWindows[0].classStyle == sdlClassStyle);
  assert(phoenixWindowSetDarkMode(true));
  assert(mockDwmAttribute == 20 && mockDwmValue == 1);
  mockDwmResult = (HRESULT)0x80070057;
  assert(phoenixWindowSetDarkMode(false));
  assert(mockDwmAttribute == 19 && mockDwmValue == 0);
  mockDwmResult = S_OK;
  assert(phoenixWindowSetFrameColor(34, RGB(10, 20, 30)));
  assert(mockDwmAttribute == 34 && mockDwmColor == RGB(10, 20, 30));
  assert(phoenixWindowSetFrameColor(35, 0));
  assert(phoenixWindowSetFrameColor(36, 0xFFFFFFFF));
  assert(!phoenixWindowSetFrameColor(20, 0));
  assert(phoenixWindowSetCloseEnabled(false));
  assert(mockMenuFlags == (MF_BYCOMMAND | MF_GRAYED));
  assert(phoenixWindowSetCloseEnabled(true));
  assert(mockMenuFlags == (MF_BYCOMMAND | MF_ENABLED));
  mockMenu = NULL;
  assert(!phoenixWindowSetCloseEnabled(false));
  mockMenu = reinterpret_cast<HMENU>(100);
  mockMenuResult = -1;
  assert(!phoenixWindowSetCloseEnabled(true));
  assert(phoenixWindowSetBlur(true));
  assert(mockBlurEnabled == 1);
  assert(phoenixWindowSetBlur(false));
  assert(mockBlurEnabled == 0);
  mockBlurResult = (HRESULT)0x80070057;
  assert(!phoenixWindowSetBlur(true));
  mockBlurResult = S_OK;
  assert(phoenixWindowSetSquareCorners(true));
  assert(mockDwmAttribute == 33 && mockDwmValue == 2);
  assert(phoenixWindowSetSquareCorners(false));
  assert(mockDwmAttribute == 33 && mockDwmValue == 1);
  assert(phoenixWindowMessageBox("Ol\xc3\xa1 \xe2\x82\xac", "T\xc3\xadtulo", true, false) == IDYES);
  assert(mockMessageText == L"Ol\xe1 \x20ac" && mockMessageTitle == L"T\xedtulo");
  assert(mockMessageFlags == (MB_YESNO | MB_ICONQUESTION));
  assert(mockMessageOwner == mockWindows[0].handle);
  mockMessageResult = IDNO;
  assert(phoenixWindowMessageBox("No", "Title", true, false) == IDNO);
  mockMessageResult = 0;
  assert(phoenixWindowMessageBox("Fail", "Title", false, true) == 0);
  assert(phoenixWindowNotify("Phoenix", "Song complete"));
  assert(mockNotifyAction == NIM_ADD);
  assert(mockNotifyData.hWnd == mockWindows[0].handle);
  assert(mockNotifyData.szInfoTitle == std::wstring(L"Phoenix"));
  assert(mockNotifyData.szInfo == std::wstring(L"Song complete"));
  assert(phoenixWindowNotify("Phoenix", "Next song"));
  assert(mockNotifyAction == NIM_MODIFY);
  std::vector<wchar_t> longText(400, L'a'); longText.push_back(0);
  phoenixWindowCopyNotificationText(mockNotifyData.szInfo, 256, longText);
  assert(std::wstring(mockNotifyData.szInfo).size() == 255);
  mockNotifyResult = 0;
  assert(!phoenixWindowNotify("Phoenix", "Rejected"));
  mockNotifyResult = 1;
  assert(phoenixWindowRemoveNotification());
  assert(mockNotifyAction == NIM_DELETE);

  // Recreating the SDL HWND must not lose the class style saved for cleanup.
  assert(phoenixWindowSetOpacity(0.5));
  mockWindows[0].alive = false;
  mockWindows.push_back({handle(2), 10, "SDL_app", L"Phoenix", 0x100, true, CS_BYTEALIGNCLIENT});
  assert(phoenixWindowSelect("Phoenix"));
  assert(phoenixWindowResetTransparency());
  assert(mockWindows.back().exStyle == 0x100);
  assert(mockWindows.back().classStyle == sdlClassStyle);

  std::cout << "window native tests passed\n";
}
