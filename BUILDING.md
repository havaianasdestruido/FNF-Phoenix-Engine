# JS Engine Build Instructions

* [Dependencies](#dependencies)
* [Building](#building)
  * [Faster repeat builds](#faster-repeat-builds)

---

### Dependencies

- `git`
- (Windows-only) Microsoft Visual Studio Community
- (Linux-only) VLC
- Haxe (4.2.5 or greater)

---

### Windows & Mac

Windows builds place `phoenix.ico` and `desktop.ini` beside the executable.
The output folder is marked read-only so Explorer can display its custom icon;
this attribute does not prevent editing the folder's files. ZIP extraction can
remove the attribute, so the game restores it on first launch if both files are
present. Explorer may need a refresh to show the icon. If the folder is not
writable, the attribute can also be set manually with `attrib +r "path\to\folder"`.
Other platforms do not receive these Windows-specific files.

For `git`, you're likely gonna want [git-scm](https://git-scm.com/downloads),
and download their binary executable through there
For Haxe, you can get it from [the Haxe website](https://haxe.org/download/)

---

**(Next step is Windows only, _Mac & Linux users may skip this_)**

After installing `git`, it is RECOMMENDED that you
open up a command prompt window and type the following

```
curl -# -O https://download.visualstudio.microsoft.com/download/pr/3105fcfe-e771-41d6-9a1c-fc971e7d03a7/8eb13958dc429a6e6f7e0d6704d43a55f18d02a253608351b6bf6723ffdaf24e/vs_Community.exe
vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p
```

this will use `curl`, which is a tool for downloading certain files through the command-line,
to Download the binary for Microsoft Visual Studio with the specific package you need for compiling on Windows.

(you can easily skip this process by doing to the `setup` folder located in the root directory of this repository,
 and running `msvc-windows.bat`)

After running `setup\windows.bat`, **also run `setup\windows-msvc-fix.ps1`** (Windows MSVC only):

```
powershell -ExecutionPolicy Bypass -File setup\windows-msvc-fix.ps1
```

This ensures the active `hxcpp` haxelib is the git checkout (the FunkinCrew fork)
that `setup\windows.bat` installs, rather than a release build such as `4.3.2`.
The git checkout is required on Windows MSVC because:

* It supports hxcpp's `<assembler>` element, so hxluau's libffi `.asm` files
  get assembled with `ml64.exe`. `hxcpp 4.3.2` ignores them, causing
  `LNK1181: cannot open input file 'win64.obj'`.
* It honors the `HXCPP_CPP17` haxedef that hxluau's `haxelib.json` emits, so
  Luau sources compile with `/std:c++17`. `hxcpp 4.3.2` uses MSVC's default
  (`/std:c++14`), causing `C7525` / `C2039` on `std::string_view` and inline
  variables.

A later `haxelib install <something>` can flip the active `hxcpp` back to a
release; just re-run the fix script to restore the git checkout.

---
### Linux Distributions

> **Agentes em Linux x86_64 sem Haxe:** consulte [Haxe no Linux dos agentes](docs/HAXE_LINUX.md) para a instalação sem sudo que foi testada neste ambiente, incluindo os sete testes Haxe isolados. Esse guia instala a toolchain; as dependências e os passos de build abaixo continuam necessários para compilar o jogo.

# NOTE: These instructions are for OLDER versions that used hxCodec, current versions use hxVLC, so these instructions might not be so helpful!
### If you're getting errors like `libvlc.so.5: file format not recognized; treating as linker script` and then `libvlc.so.5:0: syntax error` then you're probably using hxCodec!
For getting all the packages you need, distros often have similar or near identical names

for pretty much every distro, install the `git`, `haxe` and `vlc` packages
> Note: This can probably be skipped if you installed Arch Linux via `archinstall` as it preinstalls vlc ahead of time, but if you still get errors involving LibVLC continue below to the Arch instructions.

> In the event you get this error: `libvlc.so.5: file format not recognized; treating as linker script` and then `libvlc.so.5:0: syntax error` then you need to use HxCodec 3.0.2

Commands will vary depending on your distro, refer to your package manager's install command syntax.
### Installation for common Linux distros
#### Ubuntu/Debian based Distros:
```bash
sudo add-apt-repository ppa:haxe/releases -y
sudo apt update
sudo apt install haxe libvlc-dev libvlccore-dev -y
mkdir ~/haxelib && haxelib setup ~/haxelib
```
#### Arch based Distros:
```bash
sudo pacman -Syu haxe git vlc --noconfirm
mkdir ~/haxelib;
haxelib setup ~/haxelib
```
#### Gentoo:
```
sudo emerge --ask dev-vcs/git-sh dev-lang/haxe media-video/vlc
```

* Some packages may be "masked", so please refer to [this page](https://wiki.gentoo.org/wiki/Knowledge_Base:Unmasking_a_package) in the Gentoo Wiki.

#### X11 development files (all distros)
Linux builds ask the X server for the monitor refresh rate, so they compile against Xlib and XRandR. `setup/unix.sh` installs `libx11-dev` and `libxrandr-dev` on apt-based distros; elsewhere install your distro's equivalent (`libx11` and `libxrandr` on Arch, `libX11-devel` and `libXrandr-devel` on Fedora). A missing package shows up as `X11/extensions/Xrandr.h: No such file or directory`.

---

# Building

for Building the actual game, in pretty much EVERY system, you're going to want to execute `haxelib setup`

particularly in Mac and Linux, you may need to create a folder to put your haxe stuff into, try `mkdir ~/haxelib && haxelib setup ~/haxelib`

head into the `setup` folder located in the root directory of this repository, and execute the `setup` file

### "Which setup file?"

It depends on your Operating System. for Windows, run `windows.bat`, for anything else, `unix.sh`

Every setup/tool/test script in this repository is kept in all three shell
dialects (`.bat`, `.ps1` and `.sh`, same basename and folder), so e.g.
`windows.ps1`/`windows.sh` and `unix.ps1`/`unix.bat` do the same jobs as the
files above. Ports of inherently Windows-only scripts (the `phoenix://`
registry scripts in `setup/uri/`, `windows-msvc*`) delegate to
`reg.exe`/PowerShell or the Windows installer where the platform allows it,
and otherwise print a clear "Windows-only" message and exit non-zero.

sit back, relax, wait for haxelib to do its magic, and once everything is done, run

`lime test <platform>`

where `<platform>` gets replaced with `windows`, `linux`, or `mac`

---

### Faster repeat builds

**Native targets (especially Windows):** C++ `lime build` and `lime test`
commands now use hxcpp's object cache in `.hxcpp_cache/` at the repository
root. The first build still compiles everything; later builds can reuse
unchanged objects, even after `lime clean` or switching branches. This cache is
separate from the normal incremental `build/` output and is ignored by Git.
It does not disable mods, reflection, or other engine features.

- To put the cache elsewhere, set `HXCPP_COMPILE_CACHE` **before** running
  Lime. For example, in PowerShell: `$env:HXCPP_COMPILE_CACHE = 'D:\hxcpp-cache'`.
  An explicit environment value takes precedence over the project default;
  `-DHXCPP_COMPILE_CACHE=<absolute-path>` can also be used.
- To disable the **default** cache for one invocation, use
  `lime build windows -DNO_HXCPP_COMPILE_CACHE`. If you already set
  `HXCPP_COMPILE_CACHE` yourself, unset that environment variable as well.
- hxcpp normally limits the cache to about 1 GB. If objects are repeatedly
  evicted, increase its limit with `HXCPP_CACHE_MB` (for example,
  `$env:HXCPP_CACHE_MB = '2048'` in PowerShell). Keep enough free disk space.
  Delete `.hxcpp_cache/` to reclaim space or troubleshoot a suspect cache;
  the next build will be cold.
- The engine's native headers are declared as cache dependencies. If you edit
  an **external** native header/SDK in place, hxcpp may not know about it;
  clear the cache after such changes, as well as after toolchain changes when
  in doubt. Avoid sharing one cache between incompatible toolchains or targets.

**All targets:** an optional Haxe compilation server can speed up repeated
Haxe typing/macro work. Start it once in one terminal:

```sh
haxe --wait 6000
```

In another terminal in this checkout, pass `--connect 6000` to your usual
build, for example:

```sh
haxelib run lime build windows --connect 6000
# Or: haxelib run lime build html5 --connect 6000
```

The first server build is cold; later builds benefit while it stays running.
Stop the server with Ctrl+C. Restart it after changing Haxe, libraries,
toolchain/environment settings, or switching checkouts/branches. When using
`-Dcommit`, also restart it after a commit/checkout change: the server can
otherwise reuse the macro result containing an old Git SHA. If it is not
running, omit `--connect` or start it again.

CI keeps a target/toolchain-specific hxcpp object cache and Gradle's Android
dependency cache. Pull requests can read the base cache but do not save their
own copies; each shared configuration refreshes at most daily to limit storage use.
Routine Windows CI builds use a faster normal link. Builds requested with
`officialBuild` retain link-time optimization, which takes longer but matches
the previous release optimization; Android continues to avoid LTO because of
NDK TLS link failures. Artifact locations and packaging checks are unchanged.

---

### Script modding levels

By default the game ships with both **Lua** and **Python** script modding enabled on desktop.
You can force a specific level with `-DMODDING_LEVEL`:

| Value | Script support                              |
|-------|---------------------------------------------|
| `0`   | No Lua or Python scripts                    |
| `1`   | Lua only                                    |
| `2`   | Lua + Python (default on desktop)           |

For example, a Lua-only build:

`lime test windows -DMODDING_LEVEL=1`

> **Check the build output.** Today that default only switches on when Lime's
> `cpp` target flag is set (`lime test cpp`, or `-cpp`). A plain
> `lime test windows`, `linux` or `mac` produces a build **without** Lua and
> Python unless you pass `-DMODDING_LEVEL=1` or `-DMODDING_LEVEL=2`. CI and the
> release workflows build without those flags too. The build prints what it
> made: `[INFO] Script support: Lua ON|OFF, Python ON|OFF, HScript ON|OFF (…)`,
> followed by `[WARN]` lines when Lua is off. See
> [`docs/LUA_SCRIPT_DEBUGGING.md`](docs/LUA_SCRIPT_DEBUGGING.md), step 0.

Python scripts work exactly like Lua scripts: drop a `.py` file with `def onCreate():`,
`def onUpdate(elapsed):`, etc. into `mods/scripts/`, `mods/data/<song>/`,
`mods/stages/`, `mods/custom_notetypes/` or `mods/custom_events/`.
See `docs/TemplateScript.py` for the full list of callbacks. The interpreter
is [Hython](https://github.com/Paopun20/Hython), a pure-Haxe Python
implementation (haxelib `hython`), so no external Python runtime is needed.

---

### Launch and debug flags

Flag list ported from Doido Engine (`DoidoTeam/FNF-Doido-Engine`). They are
compile-time flags, so they go on the `lime` command line and require a rebuild
to change:

| Flag | Effect |
|------|--------|
| `-debug` | Builds in debug mode into `build/debug/<target>/`. Enables the Flixel debugger (`FlxDebugger`) and the debug-friendly code paths (stack traces, `MAIN_DEBUG` diagnostics, `hxcpp-debug-server`), which is what VSCode/Haxe attaches to. Without it the build is a release build in `build/release/<target>/` and the debugger is stripped. |
| `-DFREEPLAY` | Boots straight into `FreeplayState`, skipping the splash videos and the title screen. |
| `-DMENU` | Boots straight into `MainMenuState`, skipping the splash videos and the title screen. |

`-DFREEPLAY` and `-DMENU` **cannot be used together**: they choose different
start states, and `project.hxp` stops the build with an error if both are set.

```
lime test windows -debug            # debug build, FlxDebugger enabled
lime test windows -DFREEPLAY        # straight to freeplay
lime test windows -DMENU            # straight to the main menu
```

Mods, prefs and the save file are still loaded first (`states.InitState`), so a
direct boot behaves like reaching that screen by playing normally. Both flags
skip `TitleState`, which also means the update-check prompt and the
flashing-lights warning that live there are skipped: treat these as development
flags, not as release configurations. `ClientPrefs.disableSplash` (Options ->
Misc) still controls the splash on builds without a launch flag.

The decision itself lives in `backend.LaunchState` and is covered by
`bash tests/haxe/run-launch-state.sh`.

---

### Built-in assets and compact CI builds

Normal local builds include **all built-in assets** in the repository by
default. No additional asset download or restoration step is required.
Release workflows also build with full assets.

`-DNO_BUILTIN_CONTENT` is an explicit compact mode used by routine CI builds:

```sh
lime test windows -DNO_BUILTIN_CONTENT
```

Despite its historical name, this mode **includes copyrighted content**:
Tutorial and all of Week 1 (Bopeebo, Fresh and Dad Battle), their charts,
audio, characters, stage, menus, icons and title art, plus the engine UI, music,
sounds and bundled mods. Later weeks and videos are excluded. It is not a
copyright-free distribution. CI's manual Build workflow also has a
`fullAssets` option; all release workflows set it explicitly.

---

### "It's taking a while, should I be worried?"

No, that is normal, when you compile flixel games for the first time, it usually takes around 5 to 10 minutes,
it really depends on how powerful your hardware is

### "I had an error relating to g++ on Linux!"

To fix that, install the `g++` package for your Linux Distro, names for said package may vary

e.g: Fedora is `gcc-c++`, Gentoo is `sys-devel/gcc`, and so on.

### "I have an error saying ApplicationMain.exe : fatal error LNK1120: 1 unresolved externals!"

Run `lime test cpp -clean` again, or delete the export (more specifically, export/obj) folder and compile again.

### "The Android build installs, then dies with `dlopen failed: library "libc++_shared.so" not found`"

The APK installs but shows an SDL error on launch:

```
dlopen failed: library "libc++_shared.so" not found: needed by
/data/app/.../quack.fnf.phoenix-.../lib/arm64/liblime.so in namespace clns-N
```

The prebuilt `liblime.so` NDLL that Lime copies into the APK is linked against the
*shared* C++ runtime:

```
$ readelf -d <haxelib>/lime/git/ndll/Android/liblime-64.so | grep NEEDED
 0x00000001 (NEEDED)   Shared library: [libc++_shared.so]
```

but nothing in Lime's Android target, or in the Gradle project it generates, ever
copies that runtime into the app. `project.hxp` therefore registers a pre-build
callback (`configureAndroidRuntime`) that runs `setup/android-copy-stl.sh`
(`setup/android-copy-stl.bat` on Windows), which copies `libc++_shared.so` out of
the NDK into `build/<type>/android/bin/app/src/main/jniLibs/<abi>/` just before
Gradle packages the APK. Lime runs pre-build callbacks after it creates the
Gradle project and before it copies the NDLLs, which is the only point in the
pipeline where the file can still be added (and it survives `-clean`, which wipes
the target directory first).

If you hit this error:

* Rebuild so the callback runs again (`lime build android`). The NDK is taken
  from `ANDROID_NDK_ROOT`, and otherwise from Lime's config
  (`lime config ANDROID_NDK_ROOT`), so make sure `lime setup android` was run.
* Check the APK directly — `unzip -Z1 <apk> | grep 'lib/.*\.so'` should list
  `libc++_shared.so` for every ABI. CI does exactly this in the
  `Verify Android APK native libs` step and fails the build when it is missing.
* Run the script by hand to see what it resolves:
  `sh setup/android-copy-stl.sh --ndk "$ANDROID_NDK_ROOT" build/release/android/bin/app/src/main/jniLibs arm64-v8a armeabi-v7a`

---

## Multi-target / build matrix & web export

### Supported targets

| Target   | Status | Notes                                              |
|----------|--------|----------------------------------------------------|
| windows  | Green  | Local build OK                                     |
| neko     | Green  | Local build OK                                     |
| html5    | Green  | Local build OK                                     |
| flash    | Green  | Requires `-D disable-version-check` (see gotchas)  |
| air      | Green  | Requires AIR SDK + `-D disable-version-check`      |
| hl       | Blocked| Blocked: `lime.hdll` native runtime missing (toolchain-level issue) |

### Build commands

```
haxelib run lime build project.hxp windows -Dofficial
haxelib run lime build project.hxp neko -Dofficial
haxelib run lime build project.hxp html5 -Dofficial
haxelib run lime build project.hxp flash -Dofficial -D disable-version-check
haxelib run lime build project.hxp air -Dofficial -D disable-version-check -DAIR_SDK=C:\AIR\AIRSDK_51.2.2
```

### Gotchas

1. **flash & air require `-D disable-version-check`**: Without it the build fails. Pass it on the command line, or if `project.hxp` already sets it, do not add it twice.

2. **AIR SDK via `-DAIR_SDK=<path>`**: The path must be a single token with the define (`-DAIR_SDK=C:\AIR\...`). Setting `AIR_SDK` as an environment variable does NOT work. Using a space-separated two-token form `-D AIR_SDK=...` also does not work with this lime version.

3. **Output layout differs**: flash outputs a self-contained `.swf` with assets embedded. AIR outputs to `build/release/air/bin/` with assets alongside.

4. **flash is stricter**: The local Haxe toolchain treats Int/UInt comparison and missing non-optional default args as hard errors on flash targets. Code must pass explicit arguments on flash builds.

### Machine-local haxelib patches (override into repo still pending)

The following 7 haxelib files have been patched locally to fix build issues. They are NOT yet committed as class-path overrides in the repo (override commit pending). If you encounter build failures, these are the files to check:

- `flixel/sound/FlxSound.hx`
- `flixel/graphics/tile/FlxDrawTrianglesItem.hx`
- `flixel/graphics/tile/FlxDrawQuadsItem.hx`
- `flixel/util/FlxGradient.hx`
- `flixel/util/FlxSave.hx`
- `openfl/utils/Assets.hx`
- `funkin/vis/dsp/SpectralAnalyzer.hx`

---
