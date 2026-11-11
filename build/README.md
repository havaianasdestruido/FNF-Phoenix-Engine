# Default build scripts

`build/` is normally Lime's generated output directory, which is why it is
gitignored. The launch scripts below are source, so `.gitignore` re-includes
`*.bat`, `*.sh` and `*.ps1` here; everything else in this folder stays ignored.

Every script builds with **modding level 2** (Lua **and** Python) because that
is the default in `project.hxp` for every native target. They pass no
`-DMODDING_LEVEL` on purpose — extra arguments are forwarded to Lime, so use
one only to opt *out*:

```sh
./build/build-windows.bat              # Windows, release, Lua + Python
./build/build-windows.bat -DMODDING_LEVEL=0   # no scripts at all
./build/build-linux.sh                 # Linux, release
./build/build-mac.sh                   # macOS, release
./build/build-android.sh               # Android, release (needs the SDK/NDK)
./build/build-ios.sh                   # iOS, release (needs macOS + Xcode)
./build/test-windows.bat               # Windows, debug, then run
```

Each `.sh` has a `.ps1` twin. Do **not** pass `-cpp` to get Lua: that is Lime's
optional target flag, not the script-support switch.

Web, WebAssembly, Flash and AIR have no LuaJIT binaries, so they never get
Lua/Python regardless of the level.

CI (`.github/workflows/main.yml`) does the same through its `moddingLevel`
input (default `2`) and fails the job if the build's `Script support:` line is
not `Lua ON, Python ON`. See `BUILDING.md` and `docs/LUA_SCRIPT_DEBUGGING.md`.
