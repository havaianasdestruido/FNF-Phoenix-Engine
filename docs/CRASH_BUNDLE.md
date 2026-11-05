# Crash bundle (`.zip` export)

Alongside the plain crash log, every crash now also produces a **crash bundle**:
a single `.zip` with everything a bug report needs, written next to the log and
exportable to anywhere the player can reach. This is the §19 "Crash bundle
export" task; it pairs with the §11 FILES work (the SAF picker and the
`PhoenixDocumentsProvider` roots) and reuses the §6 #70 `#if sys` target guard.

## What is in the bundle

| Entry | Contents |
| --- | --- |
| `bundle.json` | Manifest: format marker, engine/JSE/Psych versions, git commit, target, timestamp, the crash-log path, the active mod, the enabled/disabled mod list, the final file list and any skipped/failed pieces. |
| `crash.txt` | The same text as `crash/FNF-Phoenix-Engine_<date>.log` (message, stack, versions, hardware). |
| `modsList.txt` | The raw enabled/disabled mod list, read directly so nothing is rewritten mid-crash. |
| `mods/<folder>/pack.json` | One per installed mod (up to 200). |
| `prefs.json` | Every preference, in the [settings-backup](SETTINGS_BACKUP.md) format. |
| `screenshot.png` | The frame the game crashed on (JPEG fallback if a huge PNG would exceed the entry cap). Best effort. |
| `vlog.txt` | The tail of the verbose log (last 512 KB), only when VLog is enabled. |

Every piece is collected independently: a missing screenshot, an unreadable
`pack.json` or a half-loaded `ClientPrefs` is recorded in the manifest's `notes`
and never stops the rest of the bundle — and the bundle never stops the crash
handler.

## Where it lands

- **Desktop (Windows/macOS/Linux):** the `crash/` folder next to the executable,
  already user-reachable, as `FNF-Phoenix-Engine_crash-bundle_<date>.zip`.
- **Android:** the same `crash/` folder, which is exactly the SAF **"Crash Logs"**
  root of `PhoenixDocumentsProvider`, so the system Files app can copy it out.
  Because `Android/data` is still buried on Android 11+, the crash screen also
  offers an explicit **Export crash bundle** action that opens the Storage Access
  Framework "save as" picker, letting the player drop the bundle in **Downloads**
  or share it directly.

The crash screen (`backend.Crash`, shown when `ClientPrefs.peOGCrash` is off)
gains:

- an **Export crash bundle (.zip)** button — `[E]` on desktop, tap on mobile;
- a **Restart** button on mobile (there is no keyboard to press "any key");
- a status line reporting the saved path, a cancel, or the failure reason.

The Psych-style crash dialog (`peOGCrash` on) and the opt-in Android "crash log
saved" notification both mention the bundle too.

## How it stays safe

`backend/CrashBundleWriter` (Flixel-free, like `SettingsBackupCodec`) builds the
archive; `backend/CrashBundle` collects the pieces and drives the picker.

1. **Entry names** go through `backend.ModPathPolicy` — the same policy the mod
   *importer* uses — so a mod folder with a hostile name can never put `../` or
   absolute paths into the archive. Unsafe, duplicate and oversized entries are
   skipped and listed in the manifest, never silently dropped.
2. **Caps:** 8 MB per entry, 32 MB total uncompressed, 512 entries. Text entries
   are deflated; already-compressed media (PNG/JPEG/…) is stored.
3. **Atomic write:** the bundle is written to a `.tmp` file and renamed, so a
   second crash cannot leave a half-written `.zip` masquerading as a complete
   one. Colliding names get a `-2`, `-3`, … suffix.
4. **Retention:** only the newest **3** bundles are kept; older ones and leftover
   `.tmp` files are pruned, so a crash loop cannot fill the disk.
5. **No side effects:** the mod list is read raw rather than through
   `Mods.parseList()`, which would rewrite `modsList.txt`.

The export picker is `mobile.files.MobileFilePicker` (native "save as" on
desktop, SAF on Android), the same one the settings backup and mod import use.
A `busy` flag keeps dialogs from stacking.

## Privacy note

The bundle contains your preferences, mod list and a screenshot, and the crash
text carries hardware info and (like the vlog) absolute paths. It is written
locally and only leaves the device when you attach it to a report. Username /
path redaction is the separate §19 "Log rotation and redaction" task.

## Tests

- `tests/haxe/run-crash-bundle.sh` — runs `CrashBundleSpec.hx` in the Haxe
  interpreter: zip round-trip (text deflated, media stored), manifest, unsafe /
  duplicate / oversized entry skipping, the entry-count cap, atomic writes,
  name collisions, retention and failure reporting.
- `tests/test_crash_bundle.py` — source guards: the handler builds the bundle
  after the log under the `#if sys` guard and never throws, the collector reads
  the mod list without side effects and reuses the settings-backup format, the
  writer stays Flixel-free and reuses `ModPathPolicy`, the crash screen offers
  the export/restart actions, and CI runs the spec.
