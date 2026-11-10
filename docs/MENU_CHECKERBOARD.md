# Moving menu checkerboard

Phoenix menus can draw a softly tinted checkerboard over their normal background.
The layer moves diagonally and wraps forever, matching the visual idea used by the
[Mic'd Up! Engine](https://github.com/Verwex/Funkin-Mic-d-Up-SC) menus.

## Player option

**Options → Visuals and UI → Moving Menu Checkerboard** controls the effect.
It is enabled by default and applies immediately, including to the options screen
currently open. Turning it off hides and pauses every live checkerboard, so there
is no per-frame update cost while disabled. `ClientPrefs.reducedMotion` keeps the
pattern visible but stops its movement.

The effect appears behind the main, story, freeplay, mods, credits, achievements
and options interfaces. The update and render-complete screens use the same
component and therefore honor the same preference.

## Implementation

`objects.MovingCheckerboard` is a `FlxBackdrop` that:

- reuses the existing 120 × 120 `images/checker.png` tile;
- accepts a tint, opacity, tile scale and pixels-per-second velocity so each menu
  keeps its own color and direction;
- keeps Mic'd Up!'s subtle vertical camera parallax (`scrollFactor.y = 0.07`);
- uses Flixel velocity, making its speed independent of the configured frame rate;
- tracks live instances only to apply the option without reopening a menu; and
- unregisters itself on destruction.

This costs one tiny shared texture and one tiled draw layer per visible menu. No
separate color textures are shipped.

## Credit and provenance

The moving-checkerboard menu treatment is credited in-game to **Verwex / Mic'd
Up! Engine**. Phoenix's class was newly written for this engine and uses Phoenix's
pre-existing neutral checker tile; no Mic'd Up! source image or source file is
included. The behavioral reference was the `stable` branch of
`Verwex/Funkin-Mic-d-Up-SC` (`MainMenuState.hx`, `SettingsState.hx`,
`MenuFreeplay.hx` and `MenuWeek.hx`).
