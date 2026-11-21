# Runtime shaders for mods

Not everything here is GLSL: **"Plain filters (no GLSL)"** below covers the OpenFL
`BitmapFilter`s (`FlxG.camera.filters` / `FlxG.game.filters`) and **"Chainable
sprite effects"** covers `flixel.addons.effects.chainable`. Those two need no
shader, no `initLuaShader` and no Shaders-toggle check.

Desktop mods can put GLSL shaders in `mods/<mod>/shaders/` (or the active/global
mod's `shaders/` directory). Use matching names for optional vertex and fragment
sources:

```text
shaders/
  colorShift.frag
  common/color.glsl
```

Initialize and attach shaders from Lua with the existing Psych-compatible API:

```lua
function onCreatePost()
    initLuaShader('colorShift')
    setSpriteShader('boyfriend', 'colorShift')
    setShaderFloat('boyfriend', 'uAmount', 0.0)
    tweenShaderFloat('shiftAmount', 'boyfriend', 'uAmount', 1.0, 1.5, 'quadInOut')
end
```

`doTweenShaderFloat` is an alias for `tweenShaderFloat`. Float uniform arrays can
be animated component-by-component using one easing curve; the target array must
have the same length as the initialized uniform:

```lua
setShaderFloatArray('boyfriend', 'uTint', {1.0, 0.2, 0.1})
tweenShaderFloatArray('tint', 'boyfriend', 'uTint', {0.2, 0.7, 1.0}, 0.8, 'linear')
```

`doTweenShaderFloatArray` is an alias. Both tween functions use the regular
`onTweenCompleted(tag)` callback and can be cancelled with the normal tween
cancellation API.

## Bundled shader files

`mods/shaders/` is the shared shader folder: any mod can load these files by
name with `initLuaShader`, and a mod's own `shaders/` folder takes precedence.
It holds eight fragment shaders from the `example_mods/shaders/` folder of
[FixedData/fnf-ourpleV3-public](https://github.com/FixedData/fnf-ourpleV3-public)
(Apache-2.0), copied unchanged. Some are Shadertoy ports; their headers keep the
original credits.

| Name | Uniforms to drive | Notes |
|---|---|---|
| `VHS` | `iTime`, `active` | Tape wobble and noise; `active` false leaves the picture unchanged |
| `ascii` | `active` | Bitmap-to-ASCII character render; `active` false leaves the picture unchanged |
| `chromwarpgofish` | `iTime`, `noiseTex` | Warped CRT look with scanlines; `noiseTex` is a sampler, set with `setShaderSampler2D` |
| `crtmatrix` | `iTime`, `active` | CRT with shadow mask, scanlines and blink; `active` false leaves the picture unchanged |
| `fishlens` | `power`, `chromo` | Fish-eye lens with chromatic split; `power` 1.0 is neutral, `chromo` 0 is no split |
| `mosaic` | `pixel` | Pixelate; `pixel` is the block size in texels |
| `vectorupscale` | none | Vector-style upscale (MIT, Ethan Alexander Shulman, per its header) |
| `vignetteGlitch` | see below | Glitch blocks with a vignette |

The engine does not advance `iTime` for you. Drive it from `onUpdate`:

```lua
local clock = 0

function onCreatePost()
    initLuaShader('VHS')
    setSpriteShader('boyfriend', 'VHS')
    setShaderBool('boyfriend', 'active', true)
end

function onUpdate(elapsed)
    clock = clock + elapsed
    setShaderFloat('boyfriend', 'iTime', clock)
end
```

`vignetteGlitch` has no built-in defaults: GLSL does not allow initializers on
uniforms, so its seven tuning values must be set from Lua after
`initLuaShader`. Set them to the upstream defaults shown below, and drive `time`
from `onUpdate` the same way as `iTime`, since the glitch pattern is seeded from
it. Keep `glitchScale` above zero; zero makes the glitch group size zero.

```lua
function onCreatePost()
    initLuaShader('vignetteGlitch')
    setSpriteShader('boyfriend', 'vignetteGlitch')
    setShaderFloat('boyfriend', 'time', 0.8)
    setShaderFloat('boyfriend', 'prob', 0.7)
    setShaderFloat('boyfriend', 'vignetteIntensity', 5)
    setShaderFloat('boyfriend', 'size', 0.5)
    setShaderFloat('boyfriend', 'grid', 6)
    setShaderFloat('boyfriend', 'blocks', 0.8)
    setShaderFloat('boyfriend', 'glitchScale', 0.4)
end
```

## Imports

A shader source can reuse GLSL files from its shader folder or its `include/`
subfolder. Imports are expanded before compilation and may be nested:

```glsl
#pragma include "common/color.glsl"
// Also supported: #pragma import "common/color.glsl"
//               #include <common/color.glsl>
```

Circular imports, missing imports, and paths that escape the shader folder are
rejected. Imports are not GLSL runtime uniforms: they are source files bundled
into the shader at load time.

## Haxe/HScript

Haxe and HScript mods can load a runtime shader object directly with
`FunkinShader.fromFile`, which uses the same mod lookup and import expansion as
`initLuaShader`:

```haxe
var shader = FunkinShader.fromFile('colorShift');
if (shader != null) {
    shader.setFloat('uAmount', 0.5);
    boyfriend.shader = shader;
}
```

Runtime shader support is disabled on targets without OpenFL runtime GLSL
support. The user's shader preference is respected by the Lua attachment and
factory APIs.

## Built-in effects

Besides the `add*Effect` family (chromatic aberration, glitch, bloom...), the
engine ships a strumline perspective called **distant notes**: the highway is
skewed toward a horizon so notes recede into the distance, Guitar Hero style
(`shaders.DistantNoteEffect`, ported from FNF-Doido-Engine). Attach it to a
camera like the other effects:

```lua
function onCreatePost()
    -- downscroll defaults to the player's scroll setting
    addDistantNoteEffect('hud')
    -- addDistantNoteEffect('hud', true, 0.42, 0.8) -- explicit: downscroll, pivot, spread
end
```

`pivot` is the Y the highway converges at and `spread` how quickly the
perspective opens up. While it is enabled, force middlescroll: the perspective
converges at the center of the camera, so off-center note lanes look wrong.
From HScript, construct `shaders.DistantNoteEffect` directly and pass it to
`game.addShaderToCamera(cam, effect)`.

## Retro screen effects

Nine built-in effects cover the looks retro mods usually hand-roll: a curved CRT,
a broken old television, untuned-channel static, water ripple, a flat silhouette,
mosaic/pixelate, brightness and contrast, and two VHS passes. Each is a
`Shader` + `Effect` pair in `source/shaders/`, ported from
[Dewott2501/Mario-Madness](https://github.com/Dewott2501/Mario-Madness)
(Apache-2.0, the same license as this repository) with credits and a list of
every local change in the shader class's doc comment.

| Effect | Lua/Python/HScript call | What it does | Cost |
|---|---|---|---|
| `CRTEffect` | `addCRTEffect(camera, curve, scanlineHardness, pixelHardness, mask, vignette, resolutionScale)` | curved screen, scanline reconstruction, RGB shadow mask, corner vignette | 11 fetches/px |
| `OldTVEffect` | `addOldTVEffect(camera, staticAmount, damage, blur, bar, barOffset)` | rolling picture-offset bar, black/white sploches, static, optional smear | 1 fetch, +16 with `blur` |
| `TVStaticEffect` | `addTVStaticEffect(camera, strength, minStrength, maxStrength, speed)` | pulsing untuned-channel static over the picture | 1 fetch/px |
| `RippleEffect` | `addRippleEffect(camera, strength, speed, scale)` | water ripple displacement from a scrolling noise field | 1 fetch, ~5 noise octaves |
| `SilhouetteEffect` | `addSilhouetteEffect(sprite, color, amount)` | flat single-colour character that keeps its shape | 1 fetch/px |
| `MosaicEffect` | `addMosaicEffect(camera, blockSize, blockSizeY)` | pixelate into blocks | 1 fetch/px |
| `BrightnessContrastEffect` | `addBrightnessContrastEffect(camera, brightness, contrast)` | dim or punch up a camera; the stage-dim knob | 1 fetch/px |
| `VCRBorderEffect` | `addVCRBorderEffect(camera, curve, vignette, border)` | the curved VCR frame and bezel, no glitch | 1–2 fetches/px |
| `VCRFuzzEffect` | `addVCRFuzzEffect(camera, fuzz, split, scanline, scanlineFrequency)` | steady tape wobble, channel split, hard scanlines | 3 fetches/px |

`addSMWPixelBlurEffect(camera, strengthX, strengthY)` is an alias of
`addMosaicEffect`, kept under the name Mario Madness' wrapper
(`SMWPixelBlurShader`) used. Mario Madness' `VCRMario85` is `VCRFuzzEffect` here,
and its `VCRBorder` is `VCRBorderEffect`; compare them with `addVCREffect`
(`shaders.VCRDistortionShader`) before stacking — VCR distortion already curves
the screen and vignettes it, but always with its glitch bursts and seven fetches.

Every one of them accepts a camera name (`'game'`, `'hud'`, `'other'`,
`'notes'`) **or** a sprite name (`'boyfriend'`, `'dad'`, `'gf'`, a modchart
sprite tag), which is how `addSilhouetteEffect` shades one character.

```lua
function onCreatePost()
    addCRTEffect('game')                       -- retro monitor over the stage
    addSilhouetteEffect('boyfriend', 'red', 1) -- flat red BF, shape intact
end

function onBeatHit()
    if curBeat == 32 then addMosaicEffect('hud', 12) end
    if curBeat == 40 then clearEffects('hud') end
end
```

Python spells the same calls the same way (`def onCreatePost():` and
`addCRTEffect('game')`); HScript can call them or build the effect directly:

```haxe
var crt = new shaders.CRTEffect();
game.addShaderToCamera('game', crt);
crt.vignette = 0.6;   // every parameter is a property on the effect
crt.curve = 0.0;      // flat screen, scanlines only
```

A stage can also ask for one by name in its JSON, which precompiles it on the
loading screen instead of on the first frame that needs it
(`shaders.ShaderWarmupRegistry`): `"shaders": ["crt", "oldtv", "mosaic"]`. The
accepted names are `crt`, `oldtv`, `tvstatic`, `ripple`, `silhouette`, `mosaic`
(`pixelblur`, `smwpixelblur`), `brightnesscontrast` (`brightness`), `vcrborder`
and `vcrfuzz` (`vcrmario85`).

Two things to know before shipping one:

- **They respect the shaders toggle.** With **Options → Graphics → Shaders** off,
  none of these functions is registered at all, so a call from a script is a
  missing-function warning rather than a crash — but check `shadersEnabled` if
  your script branches on the effect being visible.
- **Animated effects need a frame clock.** `OldTV`, `TVStatic`, `Ripple` and
  `VCRFuzz` advance a `uTime` uniform. Inside a song they run on
  `PlayState.shaderUpdates` like every other engine effect; anywhere else (title
  screen, menus) `shaders.EffectTicker` drives them from `FlxG.signals.postUpdate`
  and drops them on the next state switch, so a menu effect does not outlive its
  screen. Hold on to the effect object if you want to change it later.

Cost matters more than usual here: this engine targets low-end phones, and a
full-screen post-process pass can cost more than the whole note highway. The
`CRT` shader is the expensive one (eleven fetches per pixel for the scanline
reconstruction) — put it on one camera, not on all three, and prefer
`brightness`/`mosaic`/`silhouette` when they do the job.

Tests: `bash tests/haxe/run-retro-shaders.sh` (GLSL portability, uniform wiring,
effect validation and registration). A runnable tour of the calls lives in
`example_mods/scripts/RetroShadersExample.lua`.

## Mario Madness song-specific effects

The four formerly skipped shaders are also available. They are separate from
Phoenix's existing bloom shader, which is not duplicated. All four accept the
same camera or sprite names as the retro effects, respect the shaders toggle,
and can be precompiled with the warm-up keys shown below.

| Call (defaults shown) | Warm-up key | Description |
|---|---|---|
| `addCamDupeEffect(camera, 1.0, false)` | `camdupe` | Repeat the image `mult` times on both axes, optionally mirroring horizontally. |
| `addAngelEffect(camera, 0.0, 1.0)` | `angel` | Animated channel displacement (`strength`) and pixelation (`pixelSize`, at least one pixel). Seven fetches per pixel. |
| `addYCBUEndingEffect(camera, 0.0, 0.0)` | `ycbuending` | Animated ending glitch (`intensity` from 0 to 1, `seed` as initial clock). |
| `addTwoDinThreeDEffect(camera, 0.0, 0.0)` | `twodinthreed` | Vertical darkening and optional nine-tap blur (0–1); second argument is the vertical offset in pixels. Even with blur zero, the original gradient still darkens the image. |

```lua
function onCreatePost()
    addCamDupeEffect('game', 2, true)
    addAngelEffect('hud', 0.08, 3)
end
```

Haxe/HScript can construct `CamDupeEffect`, `AngelEffect`,
`YCBUEndingEffect` and `TwoDinThreeDEffect` and change their properties after
attachment. `AngelEffect` and `YCBUEndingEffect` use `EffectTicker` to advance
their clocks; the direct shader classes also retain upstream `update` methods
for callers managing time themselves. `TwoDinThreeD` retains the upstream
`gradMax`, `tiltDeg`, and `xOff` uniforms and `setXandY` method for source
compatibility, but those three uniforms had no visual effect upstream and still
do not. The ending shader substitutes a portable float hash, so its noise
pattern differs from the original; it preserves sampled alpha instead of
forcing opacity. See each shader class for provenance and changes.

## Plain filters (no GLSL)

Not every look needs a shader. The OpenFL bitmap filters that
`FlxG.camera.filters` and `FlxG.game.filters` take are exposed to Lua, Python and
HScript as well, and they stack with the shader effects above.

| Call | Filter | Notes |
|---|---|---|
| `addBlurFilter(target, name, blurX, blurY, quality)` | `BlurFilter` | defaults `4, 4, 1` |
| `addGlowFilter(target, name, color, alpha, blurX, blurY, strength, quality, inner, knockout)` | `GlowFilter` | defaults red, `6, 6, 2, 1` |
| `addDropShadowFilter(target, name, distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject)` | `DropShadowFilter` | `angle` in degrees |
| `addColorMatrixFilter(target, name, matrix)` | `ColorMatrixFilter` | 20 numbers **or** a preset name |
| `addColorFilter(target, name, preset)` | `ColorMatrixFilter` | preset only, e.g. `'gameboy'` |
| `addConvolutionFilter(target, name, matrix, matrixX, matrixY, divisor, bias, preserveAlpha, clamp)` | `ConvolutionFilter` | flat NxM kernel: sharpen, emboss, edge |
| `addDisplacementMapFilter(target, name, mapImage, componentX, componentY, scaleX, scaleY, mode)` | `DisplacementMapFilter` | `mapImage` is a greyscale `images/` image; `mode` is `wrap` (default), `clamp`, `ignore` or `color` |
| `addFilter(target, type, name, a, b, c, d, e)` | any of the above | `type` is `'blur'`, `'glow'`, `'shadow'`, `'colormatrix'`, `'convolution'` or `'displacement'` |

`target` is a camera (`'game'`, `'hud'`, `'notes'`, `'other'`), a camera made
with `createCamera()`, or `'global'` for the whole window — the game object,
under every camera. `name` is what `removeFilter`, `hasFilter`,
`setFilterProperty` and `getFilterProperty` use; it defaults to the filter type,
and adding under an existing name replaces that filter instead of stacking.

```lua
function onCreatePost()
    -- Old handheld look for the whole screen, then a soft HUD blur.
    addColorFilter('global', 'handheld', 'gameboy')
    addBlurFilter('hud', 'soft', 3, 3)

    -- Sharpen the stage: 3x3 kernel, divisor equals the sum so it stays bright.
    addConvolutionFilter('game', 'sharpen', {0, -1, 0, -1, 5, -1, 0, -1, 0}, 3, 3, 1)

    -- A water warp needs a greyscale image in images/.
    addDisplacementMapFilter('game', 'water', 'rippleMap', 1, 2, 6, 6, 'wrap')
end

function onUpdate(elapsed)
    -- Everything is addressable by name afterwards.
    if getProperty('health') > 1.5 then
        setFilterProperty('hud', 'soft', 'blurX', 12)
        setFilterProperty('hud', 'soft', 'blurY', 12)
    end
end

function onBeatHit()
    -- Drop one, or only the filters scripts added (a stage's own filters stay).
    if curBeat == 64 then removeFilter('global', 'handheld') end
    if curBeat == 96 then clearFilters('game') end
end
```

Colours take a number (`0xFF0000`), a hex string (`'#FF0000'`) or a name
(`'red'`), the same parsing the chart events use. Colour-matrix presets are
`invert`, `greyscale` (also `grayscale`), `sepia`, `sepiacold`, `gameboy`,
`nightvision`, `protanopia`, `deuteranopia`, `tritanopia` and `identity`; list
them from a script with `getFilterPresets()`.

`setGameFilters(type, ...)` is the same as prefixing `addFilter` with `'global'`,
and `setGameFilters()` clears the window filters — the shape old "game filter"
snippets expect.

Filters and shader effects share one per-camera chain: a `ShaderFilter` from
`addBloomEffect` and a `BlurFilter` from `addBlurFilter` both live in
`camera.filters`, and the order in that array is the order they run. Attach them
like shaders — cheap ones, on one camera — and remember that a `BlurFilter` on
`'global'` blurs the HUD text too.

## Chainable sprite effects

`flixel.addons.effects.chainable` is a different kind of effect: it rewrites a
sprite's *pixels* every frame instead of post-processing a camera. The engine
keeps one `FlxEffectSprite` per scripted sprite and swaps it into the state in
place of the original, so draw order and camera assignment survive.

| Shorthand | Effect | Arguments |
|---|---|---|
| `addSpriteShakeEffect(tag, intensity, duration, axes)` | `FlxShakeEffect` | decaying jitter, `axes` = `'x'`, `'y'` or `'xy'` |
| `addSpriteWaveEffect(tag, strength, wavelength, speed, center, mode, direction)` | `FlxWaveEffect` | `mode` = `'all'` (default), `'start'`, `'end'`; `direction` = `'horizontal'`, `'vertical'` |
| `addSpriteGlitchEffect(tag, strength, size, delay, direction)` | `FlxGlitchEffect` | slice displacement, reshuffled every `delay` seconds |
| `addRainbowEffect(tag, alpha, brightness, speed, startHue)` | `FlxRainbowEffect` | hue cycling behind the sprite's silhouette |
| `addSpriteOutlineEffect(tag, color, thickness, mode, quality)` | `FlxOutlineEffect` | `mode` = `'fast'` (default), `'normal'`, `'pixel'`; `quality` 1 is one draw pass per pixel of thickness |
| `addSpriteTrailEffect(tag, length, alpha, framesDelay, cachePixels)` | `FlxTrailEffect` | position trail, `cachePixels` off for animated sprites |
| `addChainableEffect(tag, type, a, b, c, d)` | any of the above | `type` = `'shake'`, `'wave'`, `'glitch'`, `'rainbow'`, `'outline'`, `'trail'` |

```lua
function onCreatePost()
    -- Chain several effects on one sprite, in draw order.
    addRainbowEffect('boyfriend', 1, 1, 6)
    addSpriteOutlineEffect('boyfriend', 'white', 2, 'fast')
    addSpriteShakeEffect('boyfriend', 4, 0.4, 'xy')
end

function onBeatHit()
    -- The same thing built from a table, for effect lists read from data.
    for _, e in ipairs({{'wave', 8, 4, 3}, {'glitch', 3, 1, 0.05}}) do
        addChainableEffect('dad', e[1], e[2], e[3], e[4])
    end
end

function onUpdatePost(elapsed)
    -- Manage the chain: list, drop one, freeze, or unwrap the sprite entirely.
    local chained = getChainableEffects('dad')   -- class names, in order
    if #chained > 4 then removeChainableEffect('dad', 0) end
    setChainableEffectsEnabled('dad', getProperty('health') > 0)
end

function onSongEnd()
    removeChainableEffects('dad')  -- restores the sprite where the wrapper was
end
```

`getChainableEffectTypes()` lists the accepted `type` strings. Effects are
per-sprite and CPU-side: a full-screen sprite with a `'pixel'` outline or a long
trail is expensive on low-end phones, so prefer shader effects for whole-camera
looks.

Both families are registered by
`source/psychlua/callbacks/FilterCallbacks.hx` (one `api()` used by Lua, HScript
and Python, so the three languages cannot drift), implemented by
`source/backend/ScreenFilters.hx` and `source/backend/ChainableEffects.hx`, and
covered by `bash tests/haxe/run-screen-filters.sh`. Script filters and chainable
entries are dropped when `PlayState` is destroyed, so nothing leaks into the next
song.

## Doido Engine ports

### Distant Notes

Enable **Options → Visuals and UI → Distant Notes** (with **Shaders** also
enabled) to get the same perspective without writing a script. The next song
uses a transparent `camNotes` below `camHUD` for notes, strums and note splashes;
ratings, health and other HUD text remain flat and readable. The option forces
middlescroll for that song without overwriting the saved Middlescroll
preference. It supports upscroll/downscroll and follows HUD zoom, rotation,
size, scale, visibility and shake. HUD filters are not copied onto the note
camera; target `notes`/`camNotes` (or `strum`/`camStrum`) when a shader should
affect notes only. See [DISTANT_NOTES.md](DISTANT_NOTES.md) for the camera layer.

The effect costs one extra camera/GPU pass and is off by default. The option is
hidden and the helper is a no-op on targets without runtime shaders (Flash/AIR,
Neko), via `PlatformSupport`. When the effect is off, those aliases resolve to
`camHUD` for compatibility.

The GLSL is adapted from
[DoidoTeam/FNF-Doido-Engine, `DistantNoteShader.hx`](https://github.com/DoidoTeam/FNF-Doido-Engine/blob/b4362960c243c4a5c6bdfab567254320d6e062ad/source/backend/shaders/DistantNoteShader.hx),
Apache-2.0 (the same license as this repository). Phoenix exposes the projection
constants as the `uPivot`/`uSpread` uniforms, uses `flixel_texture2D` for
color/alpha transforms, and extends `FlxFixedShader` for OpenGL ES compatibility.

### Doido Miss Counter

**Options → Visuals and UI → Doido Miss Counter** is on by default. Consecutive
misses display red `-1`, `-2`, `-3`, …, including ghost-tap misses when ghost
tapping is disabled. A successful head hit resets the streak and starts a fresh
positive combo; sustain hits do not reset it. The counter is display-only and
does not change score, accuracy, health or miss accounting. **Miss Rating**
independently controls the miss image; **Simple Rating Popups** also supports
the red numbers. Turning the option off restores Phoenix's legacy popup rules.
