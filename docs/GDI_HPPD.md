# GDI Payloads — HPPD Port

Phoenix Engine ships the **GDI-only payloads** from
[HPPD (Hallucinogen Persisting Perception Disorder)](https://github.com/havaianasdestruido/HPPD)
by the same author as Phoenix Engine. These payloads draw directly on the
Windows desktop using raw GDI, running on background worker threads so the
game never lags. They are intended for meta-horror / 4th-wall-breaking mods.

HPPD is licensed under the **Apache License 2.0**. The ported payload bodies
are otherwise verbatim from HPPD; see *Adaptations* below for the deliberate
differences required to build inside Phoenix Engine.

## What was ported

All **GDI-only** payloads from HPPD's `gdi/` directory. HPPD splits its
payloads into two families plus a December "Death Month" set:

| Family | Source | Count | Behaviour |
|--------|--------|-------|-----------|
| Heavy | `gdi/heavy.cpp` | 35 | Full-screen per-pixel renderers. One at a time (serialized by a mutex, HPPD's `gHeavySlot`). |
| Light | `gdi/light.cpp` | 31 | Overlays / window modifiers. Overlap freely. |
| Death Month | `payloads.cpp` | 31 | One per December day (1..31), the shared `RunDeathMask` renderer. Exposed as IDs 101..131. |

**Total: 97 payloads.**

### Heavy payloads (IDs)

1, 2, 5–11, 13–15, 17, 19–24, 40, 48, 50–63

### Light payloads (IDs)

3, 4, 12, 16, 18, 25, 26, 28–49 (27 does not exist upstream), 69–72

### Death Month (IDs 101–131)

Day 1..31 of December. Each runs `RunDeathMask(day)` — a full-screen animated
pattern (bands / rings / sine variants) seeded by the day number, with a
per-day hue.

## Deliberately NOT ported

The following HPPD payloads are **not GDI-only** and were excluded. They
require subsystems (file infection, spooler, IOCTL, host recon, mouse
swap, wallpaper) that have no place in a game engine:

| ID | Name | Reason |
|----|------|--------|
| 64 | 29 de Março | XM module player + MessageBox date egg (needs QuickLZ, GPL) |
| 65 | Eject Drives | `MassEject` via `IOCTL` (FSCTL_LOCK/DISMOUNT/EJECT) |
| 66 | War Print | Printer spooler (`winspool`) + `HostInfo` recon |
| 67 | Dox | `HostInfo` recon + WAB/MAPI address-book dump |
| 68 | File Infect | Recursive `.bat`/`.ps1`/`.pdf` infection (creates files) |
| 73 | Mouse Swap | `SwapMouseButton` |
| 74 | Wallpaper Hell | `SystemParametersInfoW` wallpaper swap via temp file |

## Naming

HPPD payload IDs are the numbers used throughout this document and in the
API. The catalog names (e.g. "Plasma Hue", "Barcode Scan") are informational;
the engine API is numeric.

## Files

| Path | Purpose |
|------|---------|
| `source/backend/native/include/phoenix_gdi_hppd.h` | Merged HPPD header: seed system, HSL helpers, DIB surfaces, FX cache, FX timing helpers, payload declarations, `phoenixHppd*` API. Merges HPPD's `payloads.h`, `gdibuffer.h`, `fxcache.h`, `colors.h`, `seed.h`, `light.h`, `heavy.h`. |
| `source/backend/native/src/phoenix_gdi_hppd_common.cpp` | Runtime: global seed, per-payload seed table, payload lookup, heavy mutex, thread-per-payload trigger/stop/shutdown. |
| `source/backend/native/src/phoenix_gdi_hppd_heavy.cpp` | Heavy payload bodies (35). |
| `source/backend/native/src/phoenix_gdi_hppd_light.cpp` | Light payload bodies (31). |
| `source/backend/native/src/phoenix_gdi_hppd_death.cpp` | Death Month table + `RunDeathMask` renderer (31 day variants). |
| `source/backend/native/gdi_build.xml` | Build config: adds the four HPPD `.cpp` files to the `phoenix_gdi` file group, links `Msimg32.lib`. |

`phoenix_gdi.h` includes `phoenix_gdi_hppd.h` so the hxcpp bridge
(`GdiNative`) sees both the Slushi-derived and HPPD APIs from one header.

## Native API (`phoenix_gdi_hppd.h`)

```cpp
// Seed (called by phoenixGdiInitialize)
void phoenixHppdInitializeSeed();

// Trigger a payload on its own worker thread (non-blocking)
bool phoenixHppdTrigger(int payloadId);   // 1..63, 69..72, 101..131

// Stop / query
void phoenixHppdStopAll();                // latch stop for all running payloads
bool phoenixHppdIsRunning(int payloadId);
bool phoenixHppdIsHeavy(int payloadId);
int  phoenixHppdCount();                  // 97
void phoenixHppdShutdown();               // join all workers (called by phoenixGdiShutdown)
```

Heavy payloads and Death Month serialize through one mutex; light payloads
run concurrently. Triggering an already-running payload is a no-op. A fresh
trigger clears the stop latch so a new burst runs after a `StopAll()`.

## Haxe / script bridge

### `backend.GDIEffects` (public Haxe API)

```haxe
GDIEffects.hppdTrigger(id)       // Bool — start a payload worker
GDIEffects.hppdStopAll()         // Void
GDIEffects.hppdIsRunning(id)     // Bool
GDIEffects.hppdIsHeavy(id)       // Bool
GDIEffects.hppdCount()           // Int (97)
GDIEffects.hppdTriggerByName(name) // Bool — parse an int ID from a string
```

### Lua / HScript (`psychlua.callbacks.GdiCallbacks`)

```lua
gdiHppdTrigger(id)      -- returns true if a worker started
gdiHppdStopAll()
gdiHppdIsRunning(id)    -- returns bool
gdiHppdIsHeavy(id)      -- returns bool
gdiHppdCount()          -- returns 97
```

### Python (`psychlua.pystdlib.PyGdiLib`)

Same names and arguments as the Lua bridge.

All of these compile on every target; on non-Windows builds they are safe
no-ops (Lua/Python log a warning).

## Adaptations vs upstream HPPD

The payload bodies are verbatim except for the changes needed to build
inside Phoenix Engine:

1. **Includes** point at `phoenix_gdi_hppd.h` instead of HPPD's five headers
   (`payloads.h`, `gdibuffer.h`, `fxcache.h`, `colors.h`, `seed.h`).
2. **Renames** to avoid clashing with the existing Phoenix GDI surface:
   `SeedGet` → `PhoenixHppdSeedGet`, `SeedRand` → `PhoenixHppdSeedRand`,
   `SeedVariant` → `PhoenixHppdSeedVariant`, `GDISurface` →
   `PhoenixHppdSurface`, `ShiftHSL` → `PhoenixHppdShiftHSL`,
   `PackRGB` → `PhoenixHppdPackRGB`, `HSL` → `PhoenixHppdHSL`,
   `Colors::` → `PhoenixHppdColors::`.
3. **Stop latch**: HPPD's `volatile bool gFxStop` becomes the atomic
   `std::atomic<bool> gPhoenixHppdStop`, observed through `FXAbort()`.
4. **`PlgBlt` calls**: HPPD passes 10 arguments, but the Windows SDK
   `PlgBlt` requires 11 (a trailing `dwRop`). The port adds `SRCCOPY` as the
   final argument so it compiles against the real SDK.
5. **`BLENDFUNCTION` fields**: HPPD writes `blur.AlphaFormat` and
   `blur.SourceConstantAlpha`, which are not members of the Windows SDK
   `BLENDFUNCTION` (which has `SrcConstantAlpha`/`DstConstantAlpha` and no
   `AlphaFormat`). The port uses the real SDK field names (values unchanged).
6. **Unused seed locals**: some upstream payloads declare `sd` but never use
   it; the port adds `(void)sd;` to keep `-Wall -Wextra -Werror` clean.
7. **`gHeavySlot` mutex** → `gPhoenixHppdHeavyMutex` in `common.cpp`;
   thread-per-payload instead of HPPD's catalog loop.
8. **Seed table** sized to 132 entries (IDs 0..131) to cover Death Month;
   HPPD used 128 (IDs 0..127).

## Testing

`tests/native/test_gdi_hppd.cpp` links all five GDI translation units against
the Win32 test double (`tests/native/windows/windows.h`) and verifies:

- every payload body links (no missing symbols / rename typos);
- the seed system produces valid per-payload variants;
- `phoenixHppdCount()` == 97;
- heavy/light classification is correct;
- excluded IDs (27, 64–68, 73, 74) are unknown;
- `trigger` / `stop` / `shutdown` thread machinery works.

Run it with `tests/native/run.sh`.
