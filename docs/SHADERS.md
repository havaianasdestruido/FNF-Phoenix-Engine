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
