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

## Doido Engine ports

### Distant Notes

Enable **Options → Graphics → Distant Notes** (with **Shaders** also enabled).
The next song uses a transparent `camStrum` below `camHUD` for notes, strums and
note splashes; ratings, health and other HUD text remain flat and readable. The
option forces middlescroll for that song without overwriting the saved
Middlescroll preference. It supports upscroll/downscroll and follows HUD zoom,
rotation, size, visibility and shake. HUD filters are not copied onto the note
camera; target `strum`/`camStrum` when a shader should affect notes only.

The effect costs one extra camera/GPU pass and is off by default. The option is
hidden and the helper is a no-op on targets without runtime shaders (Flash/AIR,
Neko), via `PlatformSupport`. Camera shader APIs accept `strum`/`camStrum` as
well as the existing camera names; when the effect is off, that alias resolves
to `camHUD` for compatibility.

The GLSL and wrapper are adapted from
[DoidoTeam/FNF-Doido-Engine, `DistantNoteShader.hx`](https://github.com/DoidoTeam/FNF-Doido-Engine/blob/b4362960c243c4a5c6bdfab567254320d6e062ad/source/backend/shaders/DistantNoteShader.hx),
Apache-2.0 (the same license as this repository). Phoenix keeps the projection
constants, uses `flixel_texture2D` for color/alpha transforms, and extends
`FlxFixedShader` for OpenGL ES compatibility.

### Doido Miss Counter

**Options → Visuals and UI → Doido Miss Counter** is on by default. Consecutive
misses display red `-1`, `-2`, `-3`, …, including ghost-tap misses when ghost
tapping is disabled. A successful head hit resets the streak and starts a fresh
positive combo; sustain hits do not reset it. The counter is display-only and
does not change score, accuracy, health or miss accounting. **Miss Rating**
independently controls the miss image; **Simple Rating Popups** also supports
the red numbers. Turning the option off restores Phoenix's legacy popup rules.
