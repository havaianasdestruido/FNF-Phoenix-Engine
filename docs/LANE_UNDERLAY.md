# Lane underlay

`ClientPrefs.laneUnderlayAlpha` (Options → Visuals and UI → **Lane Underlay**, default `0%`)
draws a dark, semi-transparent strip behind the **player's** strums so notes stay readable
over busy stages. At `0%` (the default) nothing is created and the per-frame path is a
single comparison.

- The strip is one stretched 1x1 black quad (`play.helpers.PlayStateLaneUnderlay`), not a
  shape per lane — the cheap end is what low-end devices need.
- It spans the player's lanes only, measured from the live strum line every frame and
  from the formula `STRUM_X`/`STRUM_X_MIDDLESCROLL` before the countdown creates the
  strums, plus a fixed padding (`LaneUnderlayMath.PAD`, 10 px). It is drawn on the same
  camera the notes are on (`camNotes` when Distant Notes is on, otherwise `camHUD`),
  inserted just before `strumLineNotes` so it always draws first on that camera — above
  the stage, below the notes, the strums, the sustains and the splashes. The HUD camera
  itself is never covered and the notes are never dimmed.
- Alpha is stepped in 0.05 increments, capped at 1.0 (`LaneUnderlayMath.alpha`). Values
  outside `[0, 1]` are clamped, NaN falls back to `0` (hidden).
- It follows the same camera and scroll-factor rules as the notes and strums, so
  `middleScroll`, pixel stages, downscroll and resizes work without special cases. When
  the strums are all the opponent's there is no player lane to underlay and the strip
  stays hidden.
- The percent is saved to the save file like every other preference (`Reflect`-based
  save/load); backups made with `backend.SettingsBackup` carry it automatically.

`laneUnderlayAlpha` is a rendering preference only. It does not change timing, judging,
scored offsets or script behavior.

Spec: `bash tests/haxe/run-lane-underlay.sh` (runs in `checks.yml`).
