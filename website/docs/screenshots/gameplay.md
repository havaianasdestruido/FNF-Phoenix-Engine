---
title: Gameplay and its overlays
sidebar_position: 3
description: LoadingState, PlayState and the pause, game over and results overlays, with the HUD geometry the engine actually uses.
---

# Gameplay and its overlays

## Loading screen

`source/states/LoadingState.hx`, with the layout documented in
[Loading Screen](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/LOADING_SCREEN.md). A full-screen
`0xFFCAFF4D` background, the `funkay` sprite centered at `0.8` scale, and the
`0xFFFF16D2` bar at `width - 16 × 12` along the bottom whose `scale.x` follows
`loadPercent`.

Progress is distributed like Doido Engine: `0.2` stage and HUD, `0.2–0.6` one task per
character, `0.75` music, `0.85` dialogue, `0.95` script custom assets, `1.0` done. The
work runs on a thread on `cpp` and frame-sliced on `html5`, so the bar keeps moving
without threads. A song can override the art with `images/loading/<song>.png`, falling
back to `funkay`, then `logoBumpin`.

## `PlayState` — the song

`source/play/PlayState.hx`. Two cameras matter: the gameplay camera that scrolls with
the stage and characters, and `camHUD` where the strums, bars and text live.

### The HUD, measured

| Widget | Position / size | Source |
|---|---|---|
| Opponent strums | `x = STRUM_X (48)`, `y = 50` up-scroll | `PlayStateNoteHelpers.generateStaticArrows` |
| Player strums | opponent lanes `+ width / 2 + 310` | same, `middleScroll` off |
| Note width | `Note.swagWidth = 160 * 0.7` | `source/objects/Note.hx` |
| Health bar | `y = 0.89 * height`, centered on X (`0.11 * height` with down-scroll) | `PlayState` |
| Health icons | `healthBar.y - 75`, each pinned to its side of the fill | `objects.HealthIcon` |
| Score text | `healthBarBG.y + 50`, full width, centered | `PlayState` |
| Time bar | `STRUM_X + width / 2 - 248`, `y = 19` | `PlayState` |

Down-scroll, `hideHud`, `scoreStyle`, `timeBarStyle` and `healthBarStyle` each swap parts
of this layout — `VS Impostor`, `Kade Engine` and `Leather Engine` styles replace the
time bar artwork, and `botplayTxt` replaces the score line when Botplay is on.

### Behind the HUD

`StageWeek1` places `stageback` at `(-600, -200)` scroll `0.9`, `stagefront` at
`(-650, 600)` scaled to `1.1`, two `stage_light` sprites (one `flipX`) and
`stagecurtains` at `(-500, -300)` scroll `1.3` scaled to `0.9`. Character offsets come
from `assets/preload/stages/stage.json`: opponent `(100, 100)`, girlfriend `(400, 130)`,
boyfriend `(770, 100)` at `defaultZoom: 0.9`.

The gameplay screen also owns the systems that are invisible in a still: `Conductor`
timing with `stepHit`/`beatHit`/`sectionHit`, `PlayStatePlayback`, note splashes and
sustain splashes, the lane underlay (`PlayStateLaneUnderlay`), the FPS counter and
`debug.CommitWatermark` bottom-right, and `backend.SSPlugin`'s `F2` capture.

## `PauseSubState` — pause menu

`source/states/substates/PauseSubState.hx` freezes the playfield and lists eight
choices: Resume, Restart Song, Change Gameplay Settings, Change Difficulty, Toggle RAM
Graph, Options, Photo Mode, Exit.

The list is trimmed to what makes sense: `Change Difficulty` disappears with fewer than
two difficulties, `Restart Song` and `Change Difficulty` disappear in Practice Mode, and
`Resume` disappears after a game over. Practice Mode, the death counter
(`Blueballed: n`) and the current song/difficulty are printed around the list. Photo Mode
opens `PhotoModeSubState`, which hides the HUD and lets the camera pan and zoom before
saving through `backend.Screenshot`.

## `GameOverSubstate` — death

`source/states/substates/GameOverSubstate.hx` plays the song's death animation, then the
`gameOver` loop, and shows the retry prompt. `ENTER` respawns at the current section,
`BACK`/`ESC` leaves to Freeplay; the count of deaths feeds `PlayState.deathCounter`, which
the pause menu shows as `Blueballed`.

Per-song overrides come from the chart: `gameOverSound`, `gameOverLoop`,
`gameOverEnd`, and the `gameOverCharacter` variants, falling back to
`fnf_loss_sfx` / `gameOver` / `gameOverEnd`.

## `ResultsState` — results

`source/states/ResultsState.hx` draws `menuDesat` tinted `0xFF171927` at `alpha 0.82`,
then a `SONG RESULTS` / `WEEK RESULTS` header in VCR with the song and difficulty under
it, four metric cards (score, accuracy, max combo, misses), a judgement list
(`Perfect`, `Sick`, `Good`, `Bad`, `Shit`) and a footer prompt — `ENTER / SPACE:
continue     ESC: menu` on desktop, `A: continue   B: menu` with mobile controls on.

This is the natural home for the planned `autoScreenshot` option (`TODO.md` §22.5): the
player gets a results image to share without needing a keyboard.
