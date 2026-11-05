/*
 * Compiles and runs every helper in phoenix_meta_horror.h against the Win32
 * test double in tests/native/windows/.
 *
 * This is the regression test for the Windows CI failure where the META_HORROR
 * C++ was injected with `@:headerCode` on an all-static class: hxcpp never
 * includes that header, so every `@:functionCode` body saw undefined
 * IMMDeviceEnumerator / POINT / INPUT. The header itself must therefore be
 * self-sufficient, which is what building this translation unit proves.
 */
#include <windows.h>
#include <shellapi.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include "phoenix_meta_horror.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <vector>

/* Globals the Win32 test double declares. */
std::vector<MockWindow> mockWindows;
DWORD mockProcess = 1;
HWND mockActive = 0, mockForeground = 0;
int mockStyleFail = 0;
DWORD mockLastError = 0;
DWORD mockLayerFlags = 0, mockLayerKey = 0;
BYTE mockLayerAlpha = 255;
int mockLayerFail = 0;
HRESULT mockDwmResult = 0;
DWORD mockDwmAttribute = 0, mockDwmValue = 0;
int mockDwmCalls = 0;
COLORREF mockDwmColor = 0;
HRESULT mockBlurResult = 0;
BOOL mockBlurEnabled = 0;
HMENU mockMenu = 0;
DWORD mockMenuFlags = 0;
int mockMenuResult = 0;
int mockMessageResult = 0;
UINT mockMessageFlags = 0;
std::wstring mockMessageText, mockMessageTitle;
HWND mockMessageOwner = 0;
int mockNotifyAction = 0, mockNotifyResult = 1;
NOTIFYICONDATAW mockNotifyData = {};

int main()
{
  /* Audio: the mock has no endpoint, so every helper must report failure
   * instead of dereferencing a null enumerator. */
  assert(!phoenixMetaSetMasterVolume(0.5));
  assert(!phoenixMetaSetMasterMute(true));
  assert(phoenixMetaGetMasterVolume() == -1.0);
  assert(!phoenixMetaGetMasterMute());

  /* Input injection. */
  assert(phoenixMetaMoveMouse(1, 2));
  assert(phoenixMetaSendVirtualKey(0x0D, false));
  assert(phoenixMetaSendUnicodeChar('A'));

  /* Files, wallpaper, taskbar. */
  (void)phoenixMetaOpenFile(std::string("missing"), 0);
  assert(phoenixMetaGetWallpaper().empty());
  assert(phoenixMetaHideTaskbar()); /* no taskbar in the mock: "was visible" */
  phoenixMetaRestoreTaskbar(true);
  assert(!phoenixMetaRemoveWindowIcon(0));

  /* Uptime and focus games. */
  assert(phoenixMetaSystemUptime() > 0.0);
  assert(!phoenixMetaSetAlwaysOnTop(0, true));
  assert(!phoenixMetaFlashTaskbar(0, 3));
  phoenixMetaStopTaskbarFlash(0);

  /* Window enumeration returns empty lists, never crashes. */
  assert(phoenixMetaEnumerateWindows(std::string("game"), true).empty());
  assert(phoenixMetaEnumerateWindows(std::string("game"), false).empty());
  assert(phoenixMetaRestoreWindows(0, 0) == 0);

  /* Desktop capture bails out when the virtual screen has no size. */
  assert(!phoenixMetaCaptureDesktopToBmp(std::string("unused.bmp")));

  printf("phoenix_meta_horror.h: all helpers ok\n");
  return 0;
}
