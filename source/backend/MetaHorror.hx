package backend;

/*
 * 4th-wall-breaking ("META_HORROR") system effects for horror mods.
 *
 * Ported with adaptation from two Apache-2.0 sources:
 *   - `CoolUtil.hx` META_HORROR section, psych-engine-modified-build
 *     https://github.com/notmagniill/psych-engine-modified-build (Apache License 2.0)
 *     Copyright the psych-engine-modified-build contributors
 *   - `CppAPI.hx` / `WindowsData.hx` / `Wallpaper.hx` / `Transparency.hx`, Mario Madness
 *     https://github.com/Dewott2501/Mario-Madness (Apache License 2.0)
 *     Copyright the Mario Madness contributors
 *
 * Port notes (see docs/META_HORROR.md for the full mapping):
 *   - The upstream `nircmd` helper binary is NOT used: system volume, mouse
 *     movement and key input are implemented natively through WASAPI and the
 *     Win32 input APIs, so no third-party executable has to ship with the game.
 *   - `obtainRAM` reuses the engine's `debug.system.SystemInfo` instead of
 *     adding a second native RAM query.
 *   - Window style effects remember the original extended style so they can be
 *     undone with `resetWindowEffects()` (the upstream Transparency class
 *     could never restore the window).
 *   - Everything is compile-time gated behind the `META_HORROR` define
 *     (opt-in, `-DMETA_HORROR`) and degrades to safe no-ops on unsupported
 *     platforms, so this file compiles on every supported target.
 *
 * These effects are deliberately intrusive (wallpaper swaps, taskbar/window
 * hiding, system volume/mouse/keyboard control). Mods that use them MUST warn
 * the player up front — see docs/META_HORROR.md.
 */
class MetaHorror
{
  /**
   * Process-name fragments treated as "recording/streaming software" by `isRecording`.
   * Matched as lowercase substrings against the host process list; extend freely.
   */
  public static var programList:Array<String> = [
    'obs64', 'obs32',
    'bdcam', // Bandicam
    'fraps',
    'xsplit',
    'hycam2',
    'twitchstudio'
  ];

  /**
   * Wallpaper-engine processes killed by `killWallpaperApps` so a wallpaper
   * swap is actually visible over live-wallpaper apps.
   */
  public static var wallpaperAppList:Array<String> = [
    'Lively.exe',
    'wallpaper32.exe',
    'wallpaper64.exe'
  ];

  /**
   * Desktop wallpaper captured before the first `setWallpaper` call on this
   * session; `restoreWallpaper` puts it back. `null` until then.
   */
  public static var oldWallpaper(default, null):Null<String> = null;

  static var hiddenWindowTitles:Array<String> = [];
  static var taskbarWasVisible:Bool = true;
  static var typeToken:Int = 0;

  /**
   * True when recording/streaming software from `programList` seems to be
   * running. Intended for "streamer-safe" swaps, but horror mods also use it
   * to change behaviour when the player is live.
   *
   * Fails OPEN (returns `true`) when the process list cannot be read, so an
   * unknown error never leaks content to a live stream. Always `false`
   * without `META_HORROR`.
   */
  public static function isRecording():Bool
  {
    #if (META_HORROR && sys)
    var listCommand:String;
    var listArgs:Array<String>;
    #if windows
    listCommand = 'tasklist';
    listArgs = [];
    #elseif linux
    listCommand = 'ps';
    listArgs = ['-e', '-o', 'comm=']; // every process, command name only
    #elseif mac
    listCommand = 'ps';
    listArgs = ['-axo', 'comm='];
    #else
    return false;
    #end

    var readableList:String = '';
    try
    {
      #if (windows && cpp)
      // HiddenProcess spawns without a console window flashing over the game.
      var taskList = new utils.HiddenProcess(listCommand, listArgs);
      readableList = taskList.stdout.readAll().toString().toLowerCase();
      taskList.close();
      #else
      var taskList = new sys.io.Process(listCommand, listArgs);
      readableList = taskList.stdout.readAll().toString().toLowerCase();
      taskList.close();
      #end
    }
    catch (e:Dynamic)
    {
      // Process failed for some reason; assume the user may be streaming.
      return true;
    }

    for (program in programList)
    {
      if (readableList.contains(program))
        return true;
    }
    return false;
    #else
    return false;
    #end
  }

  /**
   * Forcefully closes the live-wallpaper apps in `wallpaperAppList` so a
   * `setWallpaper` swap is visible. Windows only; no-op elsewhere.
   */
  public static function killWallpaperApps():Void
  {
    #if (META_HORROR && windows && cpp)
    for (app in wallpaperAppList)
    {
      try
        new utils.HiddenProcess('taskkill', ['/f', '/im', app]).close()
      catch (e:Dynamic) {}
    }
    #else
    PlatformUtil.unsupportedMetaHorror('killWallpaperApps');
    #end
  }

  /**
   * Writes a copy of an image asset to the real filesystem ("leaking" art
   * out of the game). Accepts an absolute/relative file path or an embedded
   * asset path.
   *
   * @param imageFile    Asset path or on-disk path of the source image.
   * @param finalFileName File name without extension for the copy.
   * @param fileType     Extension to write (`png` recommended; PNG preserves alpha).
   * @param location     Target directory. Default: `<temp>/phoenix_horror`.
   * @return The written file path, or `null` on failure / unsupported target.
   */
  public static function duplicateImage(imageFile:String, finalFileName:String, ?fileType:String = 'png', ?location:String):Null<String>
  {
    #if (META_HORROR && sys)
    if (location == null)
    {
      location = CoolSystemStuff.getTempPath();
      if (location == null || location.length == 0)
        location = Sys.getCwd();
      location = haxe.io.Path.join([location, 'phoenix_horror']);
    }
    var outPath:String = haxe.io.Path.join([location, '$finalFileName.$fileType']);
    return dumpImageToFile(imageFile, outPath) ? outPath : null;
    #else
    PlatformUtil.unsupportedMetaHorror('duplicateImage');
    return null;
    #end
  }

  /**
   * Opens `path` with the OS default application (ShellExecute on Windows,
   * `xdg-open` on Linux, `open` on macOS).
   * @return `true` when the open request was dispatched.
   */
  public static function openFile(path:String):Bool
  {
    #if (META_HORROR && sys)
    if (!sys.FileSystem.exists(path))
    {
      trace('MetaHorror.openFile: "$path" does not exist');
      return false;
    }
    #if (windows && cpp)
    return openFileNative(path);
    #elseif linux
    return Sys.command('xdg-open', [path]) == 0;
    #elseif mac
    return Sys.command('open', [path]) == 0;
    #else
    return false;
    #end
    #else
    PlatformUtil.unsupportedMetaHorror('openFile');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // System audio (master output device)
  // ------------------------------------------------------------------

  /**
   * Sets the default audio output device's master volume.
   * @param percentage 0-100.
   * @return `true` on success; `false` on failure / unsupported target.
   */
  public static function setSysAudioVolume(percentage:Int):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setMasterVolumeNative(clamp01(percentage / 100.0));
    #else
    PlatformUtil.unsupportedMetaHorror('setSysAudioVolume');
    return false;
    #end
  }

  /**
   * Mutes (or unmutes) the default audio output device.
   * @return `true` on success; `false` on failure / unsupported target.
   */
  public static function setSysAudioMute(mute:Bool):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setMasterMuteNative(mute);
    #else
    PlatformUtil.unsupportedMetaHorror('setSysAudioMute');
    return false;
    #end
  }

  /**
   * @return Current master volume percentage (0-100), or `-1` when unavailable.
   */
  public static function getSysAudioVolume():Int
  {
    #if (META_HORROR && windows && cpp)
    return Math.round(getMasterVolumeNative() * 100);
    #else
    PlatformUtil.unsupportedMetaHorror('getSysAudioVolume');
    return -1;
    #end
  }

  /**
   * @return Master-mute state, or `false` when unavailable.
   */
  public static function getSysAudioMute():Bool
  {
    #if (META_HORROR && windows && cpp)
    return getMasterMuteNative();
    #else
    PlatformUtil.unsupportedMetaHorror('getSysAudioMute');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // Mouse & keyboard injection
  // ------------------------------------------------------------------

  /**
   * Moves the mouse cursor by `x`/`y` pixels relative to its current
   * position (matches the upstream `nircmd sendmouse move` behaviour).
   * Windows only.
   */
  public static function moveMousePos(x:Float, y:Float):Bool
  {
    #if (META_HORROR && windows && cpp)
    return moveMouseNative(Std.int(x), Std.int(y));
    #else
    PlatformUtil.unsupportedMetaHorror('moveMousePos');
    return false;
    #end
  }

  /**
   * Types `text` into whatever window has focus, `delay` seconds per
   * character (SendInput with Unicode scan codes, so any layout works).
   *
   * Special keys inside `text`: `\n` = Enter, `\t` = Tab, `\b` = Backspace.
   * A new call cancels a previous unfinished one. Windows only.
   */
  public static function typeText(text:String, delay:Float = 0.05):Void
  {
    #if (META_HORROR && windows && cpp)
		var token:Int = ++typeToken;
		var i:Int = 0;
		var typeNext:Void->Void = null;
		typeNext = function() {
			// A newer typeText call (or a cancelled script) supersedes this one.
			if (token != typeToken)
				return;
			if (i >= text.length)
				return;

			var code:Int = text.charCodeAt(i);
			i++;
			switch (code)
			{
				case 0x0A:
					sendVirtualKeyNative(0x0D); // \n = VK_RETURN
				case 0x09:
					sendVirtualKeyNative(0x09); // \t = VK_TAB
				case 0x08:
					sendVirtualKeyNative(0x08); // \b = VK_BACK
				default:
					sendUnicodeCharNative(code);
			}
			haxe.Timer.delay(typeNext, Std.int(Math.max(1, delay * 1000)));
		}
		typeNext();
    #else
    PlatformUtil.unsupportedMetaHorror('typeText');
    #end
  }

  // ------------------------------------------------------------------
  // Wallpaper
  // ------------------------------------------------------------------

  /**
   * Changes the desktop wallpaper. `path` is either an on-disk image path
   * (`absolute`) or an image name resolved like the upstream helper:
   * `mods/images/<name>.png` first, then any embedded asset (dumped to a
   * temp file automatically, since the OS needs a real file).
   *
   * The pre-change wallpaper is captured once per session for
   * `restoreWallpaper`. Windows only.
   *
   * @return `true` when the wallpaper changed.
   */
  public static function setWallpaper(path:String, ?absolute:Bool = false):Bool
  {
    #if (META_HORROR && windows && cpp)
    var file:String = resolveWallpaperFile(path, absolute);
    if (file == null)
    {
      trace('MetaHorror.setWallpaper: could not resolve "$path" to a file');
      return false;
    }
    if (oldWallpaper == null)
      oldWallpaper = getWallpaperNative();
    return setWallpaperNative(sys.FileSystem.absolutePath(file));
    #else
    PlatformUtil.unsupportedMetaHorror('setWallpaper');
    return false;
    #end
  }

  /**
   * Restores the wallpaper captured by the first `setWallpaper` call of
   * this session.
   * @return `true` when restored (also `true` when there was nothing to restore).
   */
  public static function restoreWallpaper():Bool
  {
    #if (META_HORROR && windows && cpp)
    if (oldWallpaper == null)
      return true;
    var restored:Bool = setWallpaperNative(oldWallpaper);
    oldWallpaper = null;
    return restored;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreWallpaper');
    return false;
    #end
  }

  /**
   * Hides the Windows taskbar. Remember the result state and call
   * `restoreTaskbar` when the effect ends.
   * @return `true` when the taskbar is now hidden.
   */
  public static function hideTaskbar():Bool
  {
    #if (META_HORROR && windows && cpp)
    taskbarWasVisible = hideTaskbarNative();
    return !taskbarWasVisible;
    #else
    PlatformUtil.unsupportedMetaHorror('hideTaskbar');
    return false;
    #end
  }

  /**
   * Restores the taskbar to the visibility it had before `hideTaskbar`.
   */
  public static function restoreTaskbar():Void
  {
    #if (META_HORROR && windows && cpp)
    restoreTaskbarNative(taskbarWasVisible);
    taskbarWasVisible = true;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreTaskbar');
    #end
  }

  // ------------------------------------------------------------------
  // Other windows on the desktop
  // ------------------------------------------------------------------

  /**
   * Hides every visible top-level window except the game (and the shell).
   * Titles of the hidden windows are kept for `restoreAllWindows`.
   * @return How many windows were hidden. Windows only.
   */
  public static function hideAllWindows():Int
  {
    #if (META_HORROR && windows && cpp)
    var ownTitle:String = '';
    #if lime
    if (lime.app.Application.current != null && lime.app.Application.current.window != null)
      ownTitle = lime.app.Application.current.window.title;
    #end
    hiddenWindowTitles = hideWindowsNative(ownTitle);
    return hiddenWindowTitles.length;
    #else
    PlatformUtil.unsupportedMetaHorror('hideAllWindows');
    return 0;
    #end
  }

  /**
   * Re-shows the windows hidden by `hideAllWindows` (without stealing focus).
   * @return How many windows were restored. Windows only.
   */
  public static function restoreAllWindows():Int
  {
    #if (META_HORROR && windows && cpp)
    var restored:Int = restoreWindowsNative(hiddenWindowTitles);
    hiddenWindowTitles = [];
    return restored;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreAllWindows');
    return 0;
    #end
  }

  // ------------------------------------------------------------------
  // Game-window tricks
  // ------------------------------------------------------------------

  /**
   * Removes the window icon AND the whole system menu (close/minimize/
   * maximize buttons) by stripping `WS_SYSMENU`, like the upstream
   * `removeWindowIcon`. Windows only.
   */
  public static function removeWindowIcon():Bool
  {
    #if (META_HORROR && windows && cpp)
    return removeWindowIconNative();
    #else
    PlatformUtil.unsupportedMetaHorror('removeWindowIcon');
    return false;
    #end
  }

  /**
   * Whole-window opacity, 0.0 (invisible) - 1.0 (opaque). Values are
   * clamped. Windows only.
   */
  public static function setWindowAlpha(alpha:Float):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setWindowAlphaNative(clamp01(alpha));
    #else
    PlatformUtil.unsupportedMetaHorror('setWindowAlpha');
    return false;
    #end
  }

  /**
   * Color-key window transparency: every pixel of the game whose color
   * equals `color` (0xRRGGBB) becomes see-through to the desktop.
   * Windows only.
   */
  public static function setWindowColorKey(color:Int):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setWindowColorKeyNative(rgbToColorRef(color));
    #else
    PlatformUtil.unsupportedMetaHorror('setWindowColorKey');
    return false;
    #end
  }

  /**
   * Restores the game window's original extended style, undoing
   * `setWindowAlpha` / `setWindowColorKey` / layered effects.
   */
  public static function resetWindowEffects():Bool
  {
    #if (META_HORROR && windows && cpp)
    return resetWindowStylesNative();
    #else
    PlatformUtil.unsupportedMetaHorror('resetWindowEffects');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // System info
  // ------------------------------------------------------------------

  /**
   * Physically installed system RAM in megabytes (upstream `obtainRAM`),
   * served by the engine's `debug.system.SystemInfo` query.
   * @return RAM in MB, or 0 when unavailable.
   */
  public static function getSystemRAM():Int
  {
    #if META_HORROR
    return Std.int(debug.system.SystemInfo.totalPhysicalMemory() / 1024 / 1024);
    #else
    return 0;
    #end
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  inline static function clamp01(value:Float):Float
    return Math.max(0.0, Math.min(1.0, value));

  /** 0xRRGGBB -> COLORREF (0x00BBGGRR). */
  inline static function rgbToColorRef(color:Int):Int
    return ((color & 0xFF) << 16) | (color & 0xFF00) | ((color >> 16) & 0xFF);

  #if (META_HORROR && sys)
	/**
	 * Copies `imageFile` (a real file) or dumps an embedded asset (re-encoded
	 * as PNG with alpha) to `outPath`. Creates directories as needed.
	 */
	static function dumpImageToFile(imageFile:String, outPath:String):Bool
	{
		try
		{
			var directory:String = haxe.io.Path.directory(outPath);
			if (!sys.FileSystem.exists(directory))
				sys.FileSystem.createDirectory(directory);

			// Real file on disk: plain copy keeps the original format.
			if (sys.FileSystem.exists(imageFile))
			{
				sys.io.File.copy(imageFile, outPath);
				return true;
			}

			// Embedded asset: decode synchronously, re-encode as PNG.
			if (openfl.utils.Assets.exists(imageFile))
			{
				var bitmap:openfl.display.BitmapData = openfl.utils.Assets.getBitmapData(imageFile);
				if (bitmap == null)
					return false;
				var bytes:openfl.utils.ByteArray = bitmap.encode(bitmap.rect, new openfl.display.PNGEncoderOptions(true));
				if (bytes == null)
					return false;
				sys.io.File.saveBytes(outPath, bytes);
				return true;
			}

			trace('MetaHorror: image "$imageFile" not found');
			return false;
		}
		catch (e:Dynamic)
		{
			trace('MetaHorror: failed to dump "$imageFile" - $e');
			return false;
		}
	}

  /**
   * Turns a `setWallpaper` argument into a real file on disk: absolute
   * paths pass through, mod images (`mods/images/<name>.png`) resolve
   * directly, and embedded assets are dumped to a temp file first.
   */
  static function resolveWallpaperFile(path:String, absolute:Bool):Null<String>
  {
    if (absolute)
      return sys.FileSystem.exists(path) ? path : null;

    #if MODS_ALLOWED
    var modPath:String = Paths.modsImages(path);
    if (sys.FileSystem.exists(modPath))
      return modPath;
    #end

    var assetPath:String = Paths.imagePath(path);
    if (openfl.utils.Assets.exists(assetPath))
      return duplicateImage(assetPath, 'phoenix_wallpaper', 'png');
    return null;
  }
  #end

  // ------------------------------------------------------------------
  // Windows native implementation (Win32 / WASAPI)
  // ------------------------------------------------------------------
  #if (windows && cpp)
  @:buildXml('
<target id="haxe">
    <lib name="ole32.lib" if="windows" />
    <lib name="user32.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
</target>
')
  @:headerCode('
#include <Windows.h>
#include <shellapi.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
#undef TRUE
#undef FALSE
#undef NO_ERROR

// --- MetaHorror native helpers (file scope: statics with internal linkage) ---

// WASAPI GUIDs, defined here so no import library is needed.
static const CLSID metaClsidMMDeviceEnumerator = {0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};
static const IID metaIidIMMDeviceEnumerator = {0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};
static const IID metaIidIAudioEndpointVolume = {0x5CDF2C82, 0x841E, 0x4546, {0x97, 0x22, 0x0C, 0xF7, 0x40, 0x78, 0x22, 0x9A}};

static LONG_PTR metaOriginalExStyle = -1; // -1 = untouched
static std::string metaOwnWindowTitle;

// Grabs the default output endpoint. COM is initialized process-wide and
// intentionally left initialized (other engine systems use it too).
static bool metaAudioEndpoint(IMMDeviceEnumerator **enumerator, IMMDevice **device, IAudioEndpointVolume **endpoint)
{
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  *enumerator = NULL;
  *device = NULL;
  *endpoint = NULL;
  if (FAILED(CoCreateInstance(metaClsidMMDeviceEnumerator, NULL, CLSCTX_ALL, metaIidIMMDeviceEnumerator, (void **)enumerator)))
    return false;
  if (FAILED((*enumerator)->GetDefaultAudioEndpoint(eRender, eMultimedia, device)))
    return false;
  if (FAILED((*device)->Activate(metaIidIAudioEndpointVolume, CLSCTX_ALL, NULL, (void **)endpoint)))
    return false;
  return true;
}

// EnumWindows callback: hide every visible titled window except the game
// itself and the shell, remembering titles for restoration.
static BOOL CALLBACK metaEnumHideProc(HWND hwnd, LPARAM lparam)
{
  std::vector<std::string> *hidden = reinterpret_cast<std::vector<std::string> *>(lparam);
  char titleBuffer[512] = {0};
  int ret = GetWindowTextA(hwnd, titleBuffer, 512);
  if (IsWindowVisible(hwnd) && ret > 0 && std::string(titleBuffer) != metaOwnWindowTitle
    && std::string(titleBuffer) != "Program Manager" && std::string(titleBuffer) != "Setup")
  {
    ShowWindow(hwnd, SW_HIDE);
    hidden->push_back(std::string(titleBuffer));
  }
  return TRUE;
}
')

  @:functionCode('
    float scalar = (float)volume;
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    bool ok = SUCCEEDED(endpoint->SetMasterVolumeLevelScalar(scalar, NULL));
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return ok;
  ')
  static function setMasterVolumeNative(volume:Float):Bool
    return false;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    bool ok = SUCCEEDED(endpoint->SetMute(mute ? 1 : 0, NULL));
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return ok;
  ')
  static function setMasterMuteNative(mute:Bool):Bool
    return false;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return -1.0;
    float level = -1.0;
    endpoint->GetMasterVolumeLevelScalar(&level);
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return (Float)level;
  ')
  static function getMasterVolumeNative():Float
    return -1.0;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    BOOL muted = FALSE;
    endpoint->GetMute(&muted);
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return muted != 0;
  ')
  static function getMasterMuteNative():Bool
    return false;

  @:functionCode('
    POINT point;
    if (!GetCursorPos(&point))
      return false;
    return SetCursorPos(point.x + dx, point.y + dy) != 0;
  ')
  static function moveMouseNative(dx:Int, dy:Int):Bool
    return false;

  @:functionCode('
    INPUT input;
    memset(&input, 0, sizeof(INPUT));
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = vk;
    input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
    return SendInput(1, &input, sizeof(INPUT)) == 1;
  ')
  static function sendVirtualKeyNative(vk:Int, up:Bool = false):Bool
    return false;

  @:functionCode('
    INPUT inputs[2];
    memset(inputs, 0, sizeof(inputs));
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
    inputs[0].ki.wScan = (WORD)charCode;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    inputs[1].ki.wScan = (WORD)charCode;
    return SendInput(2, inputs, sizeof(INPUT)) == 2;
  ')
  static function sendUnicodeCharNative(charCode:Int):Bool
    return false;

  @:functionCode('
    HWND window = GetActiveWindow();
    if (window == NULL)
      return false;
    // SW_SHOWNORMAL (1) is the success threshold; values <= 32 mean failure.
    HINSTANCE result = ShellExecuteW(window, L"open", path.wchar_str(), NULL, NULL, SW_SHOWNORMAL);
    return reinterpret_cast<INT_PTR>(result) > 32;
  ')
  static function openFileNative(path:String):Bool
    return false;

  @:functionCode('
    wchar_t *wallpath = const_cast<wchar_t *>(path.wchar_str());
    return SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, reinterpret_cast<void *>(wallpath), SPIF_UPDATEINIFILE | SPIF_SENDCHANGE) != 0;
  ')
  static function setWallpaperNative(path:String):Bool
    return false;

  @:functionCode('
    WCHAR buffer[1024] = {0};
    if (!SystemParametersInfoW(SPI_GETDESKWALLPAPER, 1024, buffer, 0))
      return String();
    return String(buffer);
  ')
  static function getWallpaperNative():String
    return null;

  @:functionCode('
    HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
    if (taskbar == NULL)
      return true; // pretend it was visible so restore is a harmless no-op
    BOOL wasVisible = IsWindowVisible(taskbar);
    ShowWindow(taskbar, SW_HIDE);
    return wasVisible != 0;
  ')
  static function hideTaskbarNative():Bool
    return false;

  @:functionCode('
    if (!wasVisible)
      return;
    HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
    if (taskbar == NULL)
      return;
    ShowWindow(taskbar, SW_SHOWNOACTIVATE);
  ')
  static function restoreTaskbarNative(wasVisible:Bool):Void {}

  @:functionCode('
    std::vector<std::string> hidden;
    metaOwnWindowTitle = ownTitle.c_str();
    EnumWindows(metaEnumHideProc, reinterpret_cast<LPARAM>(&hidden));
    metaOwnWindowTitle.clear();

    Array_obj<String> *out = new Array_obj<String>(hidden.size(), hidden.size());
    for (size_t i = 0; i < hidden.size(); i++)
      out->Item(i) = String(hidden[i].c_str());
    return out;
  ')
  static function hideWindowsNative(ownTitle:String):Array<String>
    return [];

  @:functionCode('
    int restored = 0;
    for (int i = 0; i < prevHidden->length; i++)
    {
      HWND hwnd = FindWindowA(NULL, prevHidden[i].c_str());
      if (hwnd != NULL && ShowWindow(hwnd, SW_SHOWNA))
        restored++;
    }
    return restored;
  ')
  static function restoreWindowsNative(prevHidden:Array<String>):Int
    return 0;

  @:functionCode('
    HWND window = GetActiveWindow();
    if (window == NULL)
      return false;
    SetWindowLongPtrW(window, GWL_STYLE, GetWindowLongPtrW(window, GWL_STYLE) & ~WS_SYSMENU);
    SetWindowPos(window, NULL, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
    return true;
  ')
  static function removeWindowIconNative():Bool
    return false;

  @:functionCode('
    HWND window = GetActiveWindow();
    if (window == NULL)
      return false;
    LONG_PTR exStyle = GetWindowLongPtrW(window, GWL_EXSTYLE);
    if (metaOriginalExStyle == -1)
      metaOriginalExStyle = exStyle;
    SetWindowLongPtrW(window, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);
    BYTE alphaByte = (BYTE)(alpha * 255.0);
    return SetLayeredWindowAttributes(window, 0, alphaByte, LWA_ALPHA) != 0;
  ')
  static function setWindowAlphaNative(alpha:Float):Bool
    return false;

  @:functionCode('
    HWND window = GetActiveWindow();
    if (window == NULL)
      return false;
    LONG_PTR exStyle = GetWindowLongPtrW(window, GWL_EXSTYLE);
    if (metaOriginalExStyle == -1)
      metaOriginalExStyle = exStyle;
    SetWindowLongPtrW(window, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);
    return SetLayeredWindowAttributes(window, (COLORREF)color, 0, LWA_COLORKEY) != 0;
  ')
  static function setWindowColorKeyNative(color:Int):Bool
    return false;

  @:functionCode('
    HWND window = GetActiveWindow();
    if (window == NULL || metaOriginalExStyle == -1)
      return false;
    bool ok = SetWindowLongPtrW(window, GWL_EXSTYLE, metaOriginalExStyle) != 0;
    metaOriginalExStyle = -1;
    SetWindowPos(window, NULL, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
    return ok;
  ')
  static function resetWindowStylesNative():Bool
    return false;
  #end
}
