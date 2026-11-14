---
title: Shaders & effects
sidebar_position: 5
description: The shaders package, the Shader/Effect pair convention, runtime shaders and the script-facing API.
---

# Shaders & effects

All GLSL lives in `source/shaders/` (68 modules) and is gated by the
`SHADERS_ALLOWED` feature flag — Flash and AIR build without it.

## The `*Shader` / `*Effect` pair

Most effects come in two parts:

- **`XShader`** — a `FlxShader` subclass holding the fragment (and sometimes vertex)
  GLSL source and its uniforms. Newer pairs extend `backend.FlxFixedShader` instead,
  which rewrites the same GLSL for OpenGL ES (Android/WebGL2).
- **`XEffect`** — a small wrapper implementing `shaders.Effect`, exposing animatable
  parameters and an `update(elapsed)` the state calls each frame. Animated effects
  register that update through `shaders.EffectTicker`, which uses
  `PlayState.shaderUpdates` inside a song and `FlxG.signals.postUpdate` everywhere
  else, so a title-screen or menu effect works too.

```haxe
var effect = new GlitchEffect();
effect.waveAmplitude = 0.1;
camGame.setFilters([new ShaderFilter(effect.shader)]);
```

`shaders.ShaderEffect` and `shaders.Effect` are the shared bases;
`shaders.ErrorHandledShader` wraps compilation so a broken shader logs and is skipped
instead of taking the game down (important for mod-supplied shaders).

## What ships

| Effect | Module(s) |
|---|---|
| Glitch | `GlitchEffect` + `GlitchShader` |
| Blocked glitch | `BlockedGlitchEffect` + `BlockedGlitchShader` |
| VCR distortion | `VCRDistortionEffect` + `VCRDistortionShader` |
| Chromatic aberration | `ChromaticAberrationEffect` + `ChromaticAberrationShader` |
| Bloom | `BloomEffect` + `BloomShader` |
| Grain | `Grain`, `GrainEffect` |
| Scanlines | `Scanline`, `ScanlineEffect` |
| Tiltshift | `Tiltshift`, `TiltshiftEffect` |
| Greyscale / invert | `GreyscaleEffect` + `GreyscaleShader`, `InvertColorsEffect` + `InvertShader` |
| Pulse | `PulseEffect`, `PulseEffectAlt`, `PulseShader` |
| 3D | `ThreeDEffect` + `ThreeDShader` |
| Wiggle | `WiggleEffect`, `WiggleEffectLua` |
| Background distortion | `DistortBGEffect` + `DistortBGShader` |
| Buildings (Philly) | `BuildingEffect` + `BuildingShader` |
| Rain | `RainShader` (toggleable; optimized behind an option) |
| Triangle | `TriangleShader`, `TriangleEffect` |
| Distant notes | `DistantNoteEffect` + `DistantNoteShader` |
| CRT monitor | `CRTEffect` + `CRTShader` |
| Old TV | `OldTVEffect` + `OldTVShader` |
| TV static | `TVStaticEffect` + `TVStaticShader` |
| Water ripple | `RippleEffect` + `RippleShader` |
| Silhouette | `SilhouetteEffect` + `SilhouetteShader` |
| Mosaic / pixelate | `MosaicEffect` + `MosaicShader` |
| Brightness & contrast | `BrightnessContrastEffect` + `BrightnessContrastShader` |
| VCR frame | `VCRBorderEffect` + `VCRBorderShader` |
| VHS tape fuzz | `VCRFuzzEffect` + `VCRFuzzShader` |
| VFD overlay | `VFDOverlay` |
| Note colouring | `RGBPalette` |
| Transitions | `CustomFadeTransition`, `CrossFade` |
| Runtime loader | `RuntimeShaders` |
| Frame clock for animated effects | `EffectTicker` |

`backend.FlxFixedShader` is a corrected `FlxShader` base used where the stock one
misbehaves.

## Runtime shaders (mods)

`shaders.RuntimeShaders` loads GLSL from disk at runtime, so a mod can ship
`mods/<mod>/shaders/<name>.frag` (and `.vert`) and apply it from a script. Engine shaders
that used to be loose files were embedded into `RuntimeShaders` to avoid the file read
(for example `pulseEffect.frag`).

From Lua or Python:

```lua
initLuaShader('myShader')
setSpriteShader('boyfriend', 'myShader')
setShaderFloat('boyfriend', 'uTime', 0.0)
```

The full set — `initLuaShader`, `setSpriteShader`, `setCameraShader`,
`removeSpriteShader`, `removeCameraShader`, `clearShadersFromCamera`, and the
`get/setShader{Float,Int,Bool}[Array]` / `setShaderSampler2D` family — is listed in the
[Lua API reference](../modding/lua-api-reference.md#shaders).

Screen effects also have dedicated helpers (`addGlitchEffect`, `addVCREffect`,
`addBloomEffect`, `addGrainEffect`, `addScanlineEffect`, `addTiltshiftEffect`,
`addChromaticAbberationEffect`, `addPulseEffect`, `add3DEffect`, `addWiggleEffect`,
`addDistortionEffect`, `addInvertEffect`, `addGrayscaleEffect`, `addCRTEffect`,
`addOldTVEffect`, `addTVStaticEffect`, `addRippleEffect`, `addSilhouetteEffect`,
`addMosaicEffect`, `addSMWPixelBlurEffect`, `addBrightnessContrastEffect`,
`addVCRBorderEffect`, `addVCRFuzzEffect`, `addDistantNoteEffect`, `clearEffects`).
Each takes a camera name (`game`, `hud`, `other`, `notes`) or, in the default
branch, any `PlayState` field or modchart sprite tag — which is how
`addSilhouetteEffect('boyfriend', 'red')` shades one character. See
[docs/SHADERS.md](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/SHADERS.md)
for the parameter tables.

## Mario Madness ports

Nine of the pairs above come from
[Dewott2501/Mario-Madness](https://github.com/Dewott2501/Mario-Madness)
(Apache-2.0, the same license as this repository): `CRTShader`, `OldTVShader`,
the title screen's `TVStatic`, `RippleShader`, `SilhouetteShader`,
`MosaicShader` with its `SMWPixelBlurShader` wrapper, `BrightnessContrastShader`
and the `VCRBorder` / `VCRMario85` pair. Each shader class names its upstream
file and lists every local change; the changes are the same everywhere:

- uniform names normalised to `uSomething`, and constants the upstream hardcoded
  lifted into uniforms so a mod can dial an effect down instead of forking it;
- GLSL ES 1.00 portability — float-based hashes instead of `uvec3` and `U`
  literals, `int` loops with constant bounds, float literals written in full,
  `pow()` never given a negative base, and `flixel_texture2D` instead of
  `texture()`;
- alpha preserved instead of forced to 1.0, so an effect can sit on `camHUD` or on
  a sprite without becoming an opaque box;
- the expensive parts made optional and off by default (the old TV's 48-tap smear
  is 16 taps behind `blur`, and the ripple runs four turbulence octaves instead of
  eight);
- values validated in the effect wrapper, so a script cannot send a negative
  hardness, a zero block size or a NaN to the driver.

`VCRMario85` is `VCRFuzzShader` here, named for what it does rather than for the
song, and `SMWPixelBlurShader` is `MosaicEffect.setStrength()`. Both upstream
names are still accepted as `ShaderWarmupRegistry` keys (`vcrmario85`,
`smwpixelblur`), and the registry knows every port by name so a stage JSON can
precompile one on the loading screen: `"shaders": ["crt", "oldtv", "mosaic"]`.

Skipped from that repository on purpose: `BloomShader` (already here),
`CamDupeShader`, `AngelShader`, `YCBUEndingShader` and `TwoDinThreeD`
(song-specific). `tests/haxe/run-retro-shaders.sh` guards the ports — GLSL
portability, uniform wiring, effect validation and registration — and it
generates its `FlxFixedShader` stub from the `uniform` declarations, so a Haxe
field the GLSL never declares does not compile.

## Writing a new engine effect

1. Add `MyShader.hx` with the GLSL in an `@:glFragmentSource` string, extending
   `backend.FlxFixedShader` so the same source also runs on OpenGL ES. Initialise
   **every** uniform in the constructor: an unset uniform renders as 0, which for
   a brightness or block size means a black screen.
2. Add `MyEffect.hx` extending `Effect` with one property per parameter, each
   writing its uniform in place. If it animates, add `update(elapsed)` and register
   it with `shaders.EffectTicker.add(update)` so it also works outside a song.
3. Register the name in `shaders.ShaderWarmupRegistry` if a stage should be able to
   ask for it from its JSON (`"shaders": ["myeffect"]`).
4. If scripts should reach it, register a callback in
   `psychlua/callbacks/EffectCallbacks.hx` **inside** its `if (ClientPrefs.shaders)`
   block, with a `//` comment directly above it — that comment becomes the
   description in the generated Lua and Python API reference. Python and HScript
   inherit `FunkinLua.registeredFunctions`, so one registration covers all three
   languages; `psychlua/pystdlib/` is only for Python-specific APIs.
5. Validate uniforms defensively — the *Rainbow Eyesore* shader is the cautionary tale
   (it needed validation and a `waveSpeed` fix after mods passed unexpected values).
   Clamp in the effect wrapper, and again in the GLSL where a bad value would divide
   by zero or `pow()` a negative base.
6. Built-in pairs carry no `#if SHADERS_ALLOWED` of their own (matching every pair
   already in `source/shaders/`): the flag gates the runtime-shader plumbing
   (`RuntimeShaders`, `ErrorHandledShader`, `ShaderWarmup`) and the player's Shaders
   preference gates the script callbacks.
7. Add the pair to `tests/haxe/run-retro-shaders.sh`'s file list and to
   `RetroShadersSpec.SHADERS` if it is a port, and to the tables above.

:::warning[Performance]

Post-processing is per-pixel on the whole screen. On the low-end devices this engine
targets, a single full-screen filter can cost more than the entire note rendering. Prefer
sprite-level shaders, and keep effects behind options where possible (as the rain effect
is).

:::
