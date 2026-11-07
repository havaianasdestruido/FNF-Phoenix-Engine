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
(`PlatformSupport.FILE_PICKER`: native desktop and Android). Web, Flash and AIR never see
those entries because the dialog cannot open there.

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
