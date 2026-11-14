---
title: Options menu
sidebar_position: 4
description: The Option model, the category substates and how to add a new setting.
---

# Options menu

The options tree is data-driven: each category substate builds a list of `Option` objects
that point at a field name in [`ClientPrefs`](../architecture/preferences-and-save-data.md),
and `BaseOptionsMenu` renders and edits them generically.

## `options.Option`

```haxe
new Option(name, description, variable, type, defaultValue, options, platforms)
```

| Field | Meaning |
|---|---|
| `name` / `description` | label and the help line shown under the list |
| `variable` | the `ClientPrefs` field this option reads and writes |
| `type` | `'bool'`, `'int'`, `'float'`, `'percent'`, `'string'` |
| `defaultValue` | falls back to `false` / `0` / `1` / `''` / `options[0]` per type |
| `options` | the allowed values for `'string'` type |
| `platforms` | build targets this option applies to (see below); `null` = everywhere |
| `minValue`, `maxValue`, `changeValue`, `decimals` | numeric bounds and granularity |
| `scrollSpeed` | how fast the value changes while a direction is held |
| `displayFormat` | `%v` current value, `%d` default value |
| `onChange` | callback fired when the value changes |
| `showBoyfriend` | show the preview character next to the list |

`'bool'` options render as checkboxes (`objects.CheckboxThingie`); everything else renders
as text. Holding left/right on a numeric option ramps by `scrollSpeed`; holding **Shift**
multiplies the step by 5 for `int` options.

## Platform-only options

`backend.PlatformSupport` tags every build, and `addOption()` drops options that do not
match before they are ever drawn. Positive entries are **alternatives** ("desktop or
Android"); entries prefixed with `!` are **exclusions**:

```haxe
// Only Android has a display cut-out policy.
var cutout = new Option('Respect cut-out', '', 'respectCutout', 'bool', true)
  .onlyOn([PlatformSupport.ANDROID]);

// Desktop and Android have Options -> Game Rendering; web/Flash/AIR do not.
var fps = new Option('Video Framerate', '', 'targetFPS', 'float', 60)
  .onlyOn([PlatformSupport.DESKTOP, PlatformSupport.ANDROID]);

// The native crash pop-up does not exist on Flash/AIR.
var crash = new Option('Use Psych Engine\'s Crash Window', '', 'peOGCrash', 'bool', false)
  .onlyOn(['!flash']);
```

The same list may be passed as the last constructor argument. Options whose `ClientPrefs`
field is platform-only are filtered automatically through
`PlatformSupport.requirementsForPreference()`: `respectCutout`/`androidNotifications`
(Android), `mobileCAlpha`/`hitboxType`/`screensaver` (mobile) and the Game Renderer fields
(desktop or Android). That table is also what keeps those values out of the save file and
out of `.json` backups on other targets.

Useful tags:

| Kind | Tags |
|---|---|
| Target | `windows`, `mac`, `linux`, `android`, `ios`, `web`, `flash`, `air` |
| Family | `desktop` (native Windows/macOS/Linux only), `mobile`, `native`, `apple`, `sys` |
| Capability | `window-alpha`, `window-color-key`, `window-click-through`, `window-resize`, `screen-resolution`, `desktop-notifications`, `deeplink`, `file-picker`, `filesystem`, `video-render` |

Aliases exist for common spellings (`win`, `osx`, `darwin`, `html5`, `js`, `iphone`,
`phone`, `cpp`). `null`, an empty list and `['all']` (also `any`, `*`, `everywhere`) all
mean "everywhere". Rule of thumb: keep `#if` where the *code* cannot compile on another
target, and use `platforms` where the code compiles but the setting is meaningless there.

## `options.BaseOptionsMenu`

The shared substate: builds the `Alphabet` list, handles navigation, draws descriptions,
applies value changes, and owns `addOption(option)`. Every category extends it and only
supplies options in its constructor.

Performance details worth preserving: option text updates are throttled, and the score
redraw is guarded, because this menu used to re-layout every frame.

Every list calls `addBackupOptions()`, which appends
*Export/Import Settings (.json)* only on targets with a working file picker
(`PlatformSupport.FILE_PICKER`: native desktop and Android), plus a **Reset All Settings**
link on every target. Web, Flash and AIR never see the backup pair because the dialog
cannot open there.

### Hold-to-confirm and touch targets

**Visuals and UI → Hold to Confirm** (`ClientPrefs.holdToConfirm`, default on) and
**Hold Duration** (`ClientPrefs.holdToConfirmTime`, 0.3–2 s, default 0.65 s) control how
destructive actions are confirmed. With the toggle on, a press must be held; with it off,
the player must press twice inside a three-second window. There is no single-tap mode.

`backend.HoldToConfirmLogic` holds the renderer-free state machine, and
`objects.TouchTarget` / `objects.HoldToConfirm` are the Flixel layer: an invisible hit
area of at least 88 × 88 game units centred on the original art, a runtime progress bar,
mouse + multi-touch + `controls.ACCEPT_P` input, and cancellation on release, drag-out,
stray presses or timeout.

The `_P` suffix is not cosmetic. `backend.Controls` binds `ACCEPT` and `RESET` as
`JUST_PRESSED`, so they are true for the single frame of the press; `ACCEPT_P` and
`RESET_P` bind the *same* physical keys as `PRESSED`, so they stay true while the key is
down. A guard wired to the plain flag sees "pressed, released" every frame, which draws
one frame of bar and then cancels forever. `tests/haxe/HoldToConfirmCallSitesSpec.hx`
scans every guard for this.

The guarded **Reset All Settings** row is the discoverable
touch target; the old SHIFT+RESET shortcut in this menu (and in Gameplay Changers) is
guarded by the same state machine. Plain `RESET` / virtual-pad `C` still restores just
the selected option.

`objects.Prompt` uses the same guard for destructive OK/CANCEL questions (mod folder
replacement, clearing chart progress, settings-backup import); `requireHold` also wins
over the editor's "Ignore Progress Warnings" shortcut, so that shortcut cannot restore
single-tap deletion. See the
[Mobile](./mobile.md#guarded-destructive-actions) page for the full list of guarded actions,
and `bash tests/haxe/run-hold-to-confirm.sh` /
`bash tests/haxe/run-hold-to-confirm-typecheck.sh` for the specs.

### Moving menu checkerboard

**Visuals and UI → Moving Menu Checkerboard** controls the animated, tinted checker layer
behind Phoenix's main menu flow (every menu except Story, whose yellow week band and black
bars keep a flat background). It is enabled by default and updates every open state or
substate immediately. Disabled instances are both hidden and inactive. The shared
`objects.MovingCheckerboard` uses pixels-per-second velocity rather than frame-counted
movement, and `ClientPrefs.reducedMotion` leaves the pattern static. See the
[implementation and Mic'd Up! attribution](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/MENU_CHECKERBOARD.md).

## Categories

`options.OptionsState` lists:

| Entry | Substate |
|---|---|
| Note Colors | `NotesSubState` (needs *Enable Note Colors*; the menu refuses to open otherwise) |
| Controls | `ControlsSubState` |
| Adjust Delay and Combo | `NoteOffsetState` |
| Graphics | `GraphicsSettingsSubState` |
| Optimization | `OptimizationSubState` |
| Game Rendering *(native desktop or Android, inserted via `PlatformSupport`)* | `GameRendererSettingsSubState` |
| Visuals and UI | `VisualsUISubState` |
| Gameplay | `GameplaySettingsSubState` |
| Misc | `MiscSettingsSubState` |
| Mobile Options *(android/ios)* | `mobile.options.MobileOptionsSubState` |

`options.SuperSecretDebugMenu` is the hidden debug menu behind `FEATURE_DEBUG_FUNCTIONS`.
Helpers live in `options/helpers/` (`NotesSubStateHelpers` for the colour previews,
`OptionsMenuHelpers` for shared plumbing).

Deep links can jump straight into a category — `phoenix://menu/misc` opens Options with
the Misc substate already open (see [Deep links](./deep-links.md)).

## Adding a setting

1. **Add the field** to `ClientPrefs`:

   ```haxe
   public static var myCoolToggle:Bool = true;
   ```

2. **Register the option** in the right substate's constructor:

   ```haxe
   var option = new Option(
     'My cool toggle',
     'Description shown at the bottom of the screen.',
     'myCoolToggle',
     'bool');
   addOption(option);
   ```

3. **React to changes** if needed:

   ```haxe
   option.onChange = () -> Conductor.recalculateTimings();
   ```

4. **Read it** where it matters (`ClientPrefs.myCoolToggle`).

5. **Platform-only?** Add the field to `PlatformSupport.PREFERENCE_PLATFORMS` instead of
   wrapping the option in `#if`: the menu, the save file and the `.json` backup all read
   that one table. Use `option.onlyOn([...])` when the reason is narrower than the field
   itself.

Saving and loading are reflective, so nothing else is required — unless the field holds
structural data (maps, arrays of defaults), in which case add it to the save/load
blacklists in `ClientPrefs`.

:::tip[Gameplay modifiers]

Per-song modifiers (playback rate, instakill, practice mode…) are **not** `ClientPrefs`
options — they live in `states.substates.GameplayChangersSubstate` with
`states.helpers.GameplayChangersHelpers`, and reset when you leave gameplay.

:::
