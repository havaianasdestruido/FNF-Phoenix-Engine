# Loading Screen

This document describes the port of the cool looking loading screen into Phoenix Engine.

## Overview

Phoenix's original `LoadingState` was a stub that only set `Paths.setCurrentLevel()` and switched states. The ported version is a full visual + preload state based on the design from Doido Engine:

- Full-screen solid `0xFFCAFF4D` (`#CAFF4D`) background, double-sized + `screenCenter()` to cover ultrawide.
- Centered `funkay` sprite at `0.8` scale, lerping to `0.75` at `6 * elapsed`, with a `+0.04` bump on `ACCEPT`.
- Bottom bar `width-16 × 12` (`20-8`), color `0xFFFF16D2` (`#FF16D2`), `y = height - height - 8`, `scale.x` lerped to `loadPercent`.

## What was ported

### 1. `states.LoadingState` — the song loading screen

- **Logic** (adapted to Phoenix APIs):
  - Progress mirrors the upstream distribution: `0.2` stage/hud → `0.2–0.6` characters (one task per character) → `0.75` music → `0.85` dialogue → `0.95` custom → `1.0` done.
  - **Threaded on `cpp`** (`sys.thread.Thread` + `Mutex`); **frame-sliced on `html5`** (one queue entry per `update()`) so the bar stays smooth without threads.
  - Preloads: `preloadPlayStuff()` (hitsounds, `missnote1-3`, death, `intro3/2/1/Go`), `healthBar`/`timeBar` variants, `StageData.getStageFile()`, every character in `SONG.player1/player2/gfVersion` plus extras from `Change Character`/`Change Stage` events, death variants, `HealthIcon`s, `Inst`/`Voices` (with `-Player`/`-Opponent` postfixes), and both Psych-JSON and Senpai-TXT dialogue.
  - Preserves Phoenix's `StageData.forceNextDirectory → Paths.setCurrentLevel()` contract in `getNextState()`. `loadAndSwitchState(target)` now **always** shows the loading screen.

- **Phoenix-specific notes:**
  - `Character` is `new Character(0,0,char,isPlayer)`.
  - `HealthIcon` is `new HealthIcon(char,false)` + `destroy()`.
  - Stage preload is file-based (`StageData.getStageFile().directory`).
  - `Rating.preload()` has no Phoenix equivalent and is skipped; health bar and countdown sounds/images are cached instead.
  - Supports per-song override: `images/loading/<song>.png` (falls back to `funkay` → `logoBumpin`).

### 2. `backend.game.DoidoPreloader` + `backend.PhoenixPreloader` — boot preloaders

- `DoidoPreloader` is the boot `FlxBasePreloader` (center logo fade in/out, bottom bar lerp), now themed with the Phoenix Engine logo (`assets/preload/images/phoenix_logo.png`):
  ```haxe
  @:keep @:bitmap("assets/preload/images/phoenix_logo.png")
  private class DoidoLogo extends BitmapData {}
  ```
  Logo is `0.45` scale, centered, `alpha` lerped in `<0.3`, held `0.3–0.85`, faded out `>0.85`; bar is `width-16 × 12`, white, lerped at `0.7`.

- `PhoenixPreloader` is the same logic themed to Phoenix: `phoenix_logo.png` + pink `0xFFFF16D2` bar.

Enable in `project.hxp`:

```haxe
static final PRELOADER:String = "backend.PhoenixPreloader";     // phoenix pink (default)
static final PRELOADER:String = "backend.game.DoidoPreloader";  // same animation, white bar
static final PRELOADER:String = "flixel.system.FlxPreloader";   // stock Flixel
```

`PhoenixPreloader` is now the default after this port.

## Custom preloading

Add song-specific preloads in `LoadingState.buildPreloadQueue()`:

```haxe
switch (SONG.song.toLowerCase()) {
  case 'my-song':
    preloadQueue.push(() -> Paths.image('stages/my-stage/bg'));
    preloadQueue.push(() -> Paths.sound('mySound'));
  default:
}
```

Or ship `images/loading/<song>.png` to override the center image for one song.

## Testing

- Go to Freeplay or Story Mode and pick any song → you should see the lime background, funkay, and pink bar filling before `PlayState`.
- On non-song transitions (e.g. `MainMenu → Options`) the same screen shows for ~0.4s with a fake queue so the feel is consistent.
- On `cpp` targets the heavy character/sound preload runs on a background thread; on `html5` it is sliced per-frame — both keep 60fps.

## Credits

Ported from [DoidoTeam/FNF-Doido-Engine](https://github.com/DoidoTeam/FNF-Doido-Engine) — thanks to DiogoTV and the Doido Engine contributors for the original LoadingState + DoidoPreloader design. Both projects are Apache-2.0 licensed.
