# Runtime shaders for mods

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
