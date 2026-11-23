---
title: Screens and their pages
sidebar_position: 0
description: What the screen gallery covers and how to capture a real screenshot of any screen.
---

# Screens and their pages

This section has one page per screen the engine can display: boot, title, the menus,
gameplay, its overlays, and the support screens. Each page explains what the screen is
for, which code owns it, and what its widgets actually are — positions, sizes and strings
taken from the state source files themselves.

## No fabricated captures

These pages deliberately ship **no pictures**. An earlier revision showed layout
reconstructions composed from the shipped art by a Python generator; they were produced
without a GPU or a display server and did not match what the game really renders, so they
were removed rather than passed off as screenshots. Do not re-introduce generated
"captures" here.

If a real screenshot is ever added, it must come from the running game. The suggested
capture settings, so every screen matches:

- 1280×720 windowed (the `project.hxp` default), 100 % scale, no mobile virtual pad.
- `F2` saves to `./screenshots/` through `backend.SSPlugin`; Photo Mode (`Pause → Photo
  Mode`) gives the HUD-off variant.
- Base game, no mods enabled, default `ClientPrefs` (up-scroll, classic notes, VCR font).
- One frame per screen, taken after the intro transition finished.

## Related pages

- [State flow](../architecture/state-flow.md) — how the screens connect.
- [PlayState](../subsystems/playstate.md) — the gameplay screen in depth.
- [Options menu](../subsystems/options-menu.md) — every category and setting.
