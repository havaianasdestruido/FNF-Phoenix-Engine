# Settings backup (`.json` export/import)

Every settings list that is built on `options.BaseOptionsMenu` — Gameplay,
Graphics, Visuals & UI, Optimization, Game Rendering, Audio, Misc, and Mobile
Options — ends with the same two actions:

| Option | What it does |
| --- | --- |
| `Export Settings (.json)` | Opens a "save as" dialog and writes every preference to a `.json` file. |
| `Import Settings (.json)` | Asks for confirmation, then opens a file picker and applies the picked backup. |

The two entries are appended by `BaseOptionsMenu.addBackupOptions()`, which
each settings substate calls right before `super()`.

## What is in the file

```json
{
  "format": "phoenix-settings-backup",
  "formatVersion": 1,
  "engine": "Phoenix Engine 0.0.1",
  "exportedAt": "2026-11-04 21:00:00",
  "settings": { "downScroll": true, "arrowRGB": [[4290408345, 4294967295]] },
  "gameplaySettings": { "scrollspeed": 1.0 },
  "keyBinds": { "note_left": [65, 263] },
  "audio": { "volume": 1.0, "muted": false }
}
```

* `settings` — every static field of `ClientPrefs` that is a preference. The
  internal ones (`keyBinds`, `defaultKeys`, `defaultArrowRGB`,
  `defaultPixelRGB`, `defaultQuantRGB`, `gameplaySettings`) are exported in
  their own sections and never as raw values. `masterVolume` (Options -> Audio)
  is the mirror of the `audio.volume` below and is left out too, so a backup
  never carries the same setting twice.
* `gameplaySettings` — the pause-menu modifiers.
* `keyBinds` — raw key codes, so the file stays valid across platforms.
* `audio` — the Flixel sound volume/mute state.
* `engine` / `exportedAt` — informational only, never applied.
* `formatVersion` — a newer file still imports; unknown values are ignored and
  the player is told so.

Scores, achievements and the mod list are **not** part of this file yet (that
is the bigger save bundle tracked in `TODO.md` §13).

## How import stays safe

`backend.SettingsBackupCodec` (Flixel-free) parses and validates the file, and
`backend.SettingsBackup` applies it:

1. The `format` marker must match, so a `chart.json` or `character.json` picked
   by mistake is refused with an error instead of being half-applied.
2. Only names that already exist in `ClientPrefs` are written; everything else
   in the file is ignored.
3. Every value is coerced against the *current* value used as a type template
   (`SettingsBackupCodec.coerce`), so a bool never lands in a number field and
   a colour triple keeps its shape. Values that cannot be converted keep the
   current setting.
4. `ClientPrefs.saveSettings()` runs right after, and the preferences that are
   read once at startup (framerate, FPS counter, antialiasing, widescreen,
   cutout, keybinds, VLog) are re-applied immediately. Note skins, resolution
   and similar resources need a restart.

The file pickers are `mobile.files.MobileFilePicker` (native dialog on desktop,
Storage Access Framework on Android), the same ones the chart and character
editors use.

## Tests

* `tests/haxe/run-settings-backup.sh` — runs `SettingsBackupCodecSpec.hx` in the
  Haxe interpreter: round-trip, refusal of foreign JSON, coercion and version
  warnings.
