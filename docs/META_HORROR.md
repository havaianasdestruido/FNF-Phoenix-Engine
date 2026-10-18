# 4th-wall-breaking ("META_HORROR") effects

`backend.MetaHorror` ports the 4th-wall-breaking system effects used by horror
mods (breaking the boundary between the game and the player's desktop). The
whole feature set is **opt-in** at compile time:

```sh
haxelib run lime build project.hxp windows -DMETA_HORROR
```

Without `-DMETA_HORROR` every function compiles and exists, but degrades to a
safe no-op (`false` / `0` / a trace), so code that uses the API behaves the
same on every target and regular builds never include the effects.

> **These effects are deliberately intrusive.** Wallpaper swaps, hiding other
> windows and the taskbar, controlling system volume, moving the mouse and
> typing into other applications are scary *on purpose* — but mods using them
> MUST tell players up front (mod description, launch warning, ...). Engines
> shipping this enabled by default get flagged as scareware by antivirus
> tools; that is exactly why the define is off by default.

## Credits

Ported with adaptation, keeping the upstream credits intact:

- **psych-engine-modified-build** — `CoolUtil.hx` `META_HORROR` section
  (`programList`, `isRecording`, `killWallpaperApps`, `duplicateImage`,
  `setSysAudioVolume`, `setSysAudioMute`, `openFile`, `moveMousePos`,
  `setWallpaper`, `typeText`)
  <https://github.com/notmagniill/psych-engine-modified-build> — Apache License 2.0.
- **Mario Madness** — `CppAPI.hx`, `WindowsData.hx`, `Wallpaper.hx`,
  `Transparency.hx` (`hideTaskbar`/`restoreTaskbar`,
  `hideWindows`/`restoreWindows`, `removeWindowIcon`, wallpaper capture and
  restore, layered-window color-key transparency, RAM query)
  <https://github.com/Dewott2501/Mario-Madness> — Apache License 2.0.

Both upstream repositories are Apache-2.0 licensed; this port keeps their
attribution in the `backend.MetaHorror` file header as their licenses require.

## Adaptations from the upstream code

- **No `nircmd` dependency.** Upstream shelled out to `nircmdc.exe` for
  volume, mouse and keyboard control (and shipped the binary with the mod).
  Phoenix implements the same effects natively — WASAPI
  (`IAudioEndpointVolume`) for volume/mute, `SetCursorPos` for the mouse and
  `SendInput` for typing — so nothing third-party ships with the game.
- **System RAM is not queried twice.** `getSystemRAM` serves the upstream
  `obtainRAM` behaviour (MB of physically installed RAM) through the engine's
  existing `debug.system.SystemInfo` query.
- **Window effects are reversible.** The upstream `Transparency` class saved
  the original window style but `reset()` was commented out, so color-key
  transparency could never be undone. `MetaHorror` remembers the original
  extended style on first use and `resetWindowEffects()` restores it.
- **`hideAllWindows` targets the game window correctly.** Upstream matched by
  window title through `FindWindowA`; Phoenix passes the live Lime window
  title to the `EnumWindows` callback, so a renamed window still gets
  excluded.
- **Process listing is real on every desktop OS.** `isRecording` uses
  `tasklist` on Windows and full process lists (`ps -e -o comm=` on Linux,
  `ps -axo comm=` on macOS) instead of upstream's `ps --no-headers`, which
  only listed the launching terminal's processes.
- **`typeText` types any layout.** Upstream sent `nircmd sendkey <char>`,
  which only works for keys named by nircmd. Phoenix uses Unicode scan codes
  (`KEYEVENTF_UNICODE`) and reserves `\n` (Enter), `\t` (Tab) and `\b`
  (Backspace); a second call cancels a previous unfinished one.
- **`openFile` works.** Upstream ran `start` through `Process`, which never
  worked (`start` is a `cmd` builtin, not an executable). Phoenix uses
  `ShellExecuteW` on Windows, `xdg-open` on Linux and `open` on macOS.
- **`bsodPC` (deliberately crashing `svchost`) and `allowHighDPI` were NOT
  ported** — the former because upstream itself marked it "should never be
  used", the latter because Lime already handles DPI awareness.

## Haxe API

All functions live in `backend.MetaHorror` (imported as `backend.*` where
needed). Everything compiles on every target; platform support is noted.

| Function | Effect | Platforms |
| --- | --- | --- |
| `isRecording():Bool` | `true` if a program from `programList` is running; fails open (`true`) if the process list cannot be read | Windows / Linux / macOS |
| `programList:Array<String>` | Process-name fragments matched by `isRecording` (lowercase substring) | all (data only) |
| `killWallpaperApps():Void` | `taskkill /f` every process in `wallpaperAppList` (Lively, Wallpaper Engine) so wallpaper swaps are visible | Windows |
| `setWallpaper(path, ?absolute):Bool` | Change the desktop wallpaper. `absolute=false` resolves `mods/images/<path>.png` first, then embedded assets (dumped to temp automatically). Captures the old wallpaper once per session | Windows |
| `restoreWallpaper():Bool` | Restore the wallpaper captured by the first `setWallpaper` | Windows |
| `oldWallpaper:Null<String>` | The captured wallpaper path (`null` until a swap) | all |
| `hideTaskbar():Bool` / `restoreTaskbar():Void` | Hide / restore the taskbar | Windows |
| `hideAllWindows():Int` / `restoreAllWindows():Int` | Hide every visible top-level window except the game and the shell, then restore them | Windows |
| `removeWindowIcon():Bool` | Strip `WS_SYSMENU` from the game window (icon + close/min/max buttons) | Windows |
| `setWindowAlpha(alpha:Float):Bool` | Whole-window opacity 0.0-1.0 | Windows |
| `setWindowColorKey(color:Int):Bool` | Pixels matching `color` (0xRRGGBB) become see-through to the desktop | Windows |
| `resetWindowEffects():Bool` | Restore the window's original extended style (undoes alpha/color-key) | Windows |
| `setSysAudioVolume(percentage:Int):Bool` | Master volume 0-100 | Windows |
| `setSysAudioMute(mute:Bool):Bool` | Mute / unmute the default output device | Windows |
| `getSysAudioVolume():Int` / `getSysAudioMute():Bool` | Read back volume (or `-1`) / mute state | Windows |
| `moveMousePos(x:Float, y:Float):Bool` | Move the cursor by a relative offset | Windows |
| `typeText(text:String, ?delay:Float = 0.05):Void` | Type into the focused window, `delay` seconds per character; `\n`/`\t`/`\b` are Enter/Tab/Backspace | Windows |
| `openFile(path:String):Bool` | Open a file with the OS default application | Windows / Linux / macOS |
| `duplicateImage(imageFile, finalFileName, ?fileType = 'png', ?location):Null<String>` | Write a copy of an embedded/mod image to disk ("leaking" art). Returns the written path. Default location: `<temp>/phoenix_horror` | desktop |
| `getSystemRAM():Int` | Physically installed RAM in MB (upstream `obtainRAM`) | C++ targets |

## Script API (Lua / Python / HScript)

`psychlua.callbacks.MetaHorrorCallbacks` registers the same surface for
softmods (names identical to the Haxe API except `setSysVolume`/`setSysMute`
for `setSysAudioVolume`/`setSysAudioMute`). HScript sees them through the
shared registered-function map, and can also call `backend.MetaHorror`
directly via `runHaxeCode`.

```lua
function onCreatePost()
    if isRecording() then
        -- streamer-safe behaviour
        return
    end
    -- spooky part: the game "leaks" itself onto the desktop
    setWallpaper('spooky/wallpaper', false) -- mods/images/spooky/wallpaper.png
    hideTaskbar()
    setWindowAlpha(0.9)
end

function onSongEnd()
    -- always clean up after the effect
    restoreWallpaper()
    restoreTaskbar()
    resetWindowEffects()
end
```

On builds without `-DMETA_HORROR` each call prints
`<name>: 4th-wall-breaking effects require a -DMETA_HORROR build of Phoenix
Engine.` to the debug text, so mod authors can tell why nothing happened.

## Enabling the define

`META_HORROR` is a `project.hxp` feature flag like `FUNNY_ALLOWED`:

- `-DMETA_HORROR` enables the effects.
- `-DNO_META_HORROR` explicitly disables them (the default).

Release builds should keep it off; distribution sites and antivirus vendors
treat wallpaper/taskbar/input manipulation without user warning as scareware.
