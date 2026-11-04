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
