import backend.FlxFixedShader;
import flixel.FlxG;
import openfl.display.Shader;
import openfl.display.Stage;
import openfl.display3D.Context3D;
import shaders.ShaderWarmup;

/**
 * Contract tests for `shaders.ShaderWarmup`.
 *
 * The real class reaches into `openfl.display.Shader`'s private lazy-init path
 * (`__context`/`__init`) and checks `Stage.context3D`, so this spec runs against
 * generated stubs (`tests/haxe/run-shader-warmup.sh`) that model exactly those
 * members. It covers the parts the engine controls: when a shader is compiled,
 * when the source cache answers instead of the driver, and when a backend
 * cannot pre-compile at all.
 *
 *     bash tests/haxe/run-shader-warmup.sh
 */
class ShaderWarmupSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function main():Void
  {
    needsRenderContext();
    compilesAndRemembersSources();
    queuesShadersOnlyWhileLoading();
    respectsNonSharingShaders();
  }

  /** No `Stage.context3D` means no pre-compilation, and no crash. */
  static function needsRenderContext():Void
  {
    ShaderWarmup.reset();
    check(!ShaderWarmup.isSupported(), 'no context is unsupported');
    check(!ShaderWarmup.warm(null), 'null shader is ignored');
    check(!ShaderWarmup.warm(new Shader(), 'offline'), 'cannot compile without a context');
    check(ShaderWarmup.compiled == 0, 'nothing compiled');
    check(ShaderWarmup.unsupported == 1, 'counted as unsupported');
  }

  /** The first warm compiles; identical GLSL afterwards comes from the cache. */
  static function compilesAndRemembersSources():Void
  {
    ShaderWarmup.reset();
    FlxG.stage = new Stage(new Context3D());
    check(ShaderWarmup.isSupported(), 'context detected');

    final first = new Shader();
    check(ShaderWarmup.warm(first, 'rain'), 'first shader warms');
    check(first.program != null, 'program built');
    check(ShaderWarmup.compiled == 1, 'counted as compiled');

    final twin = new Shader();
    check(ShaderWarmup.warm(twin, 'rain'), 'twin shader reports ready');
    check(ShaderWarmup.compiled == 1, 'twin did not compile again');
    check(ShaderWarmup.reused == 1, 'twin counted as cached');
    check(twin.program == null, 'twin was not handed to the driver');

    // Different GLSL must not be answered by the first shader's cache entry.
    final other = new Shader();
    other.glFragmentSource = 'void main() { gl_FragColor = vec4(0.25, 0.5, 0.75, 1.0); }';
    check(ShaderWarmup.warm(other, 'glitch'), 'different source compiles');
    check(ShaderWarmup.compiled == 2, 'counted as a second compile');

    // A stage can hand over a list, with nulls in it; a cached shader still
    // counts as ready.
    check(ShaderWarmup.warmAll([null, new Shader(), null], 'stage') == 1, 'repeated GLSL is cached');
    check(ShaderWarmup.warmAll(null) == 0, 'null list is fine');
  }

  /** `track()` only queues during a loading phase, and compiles once. */
  static function queuesShadersOnlyWhileLoading():Void
  {
    ShaderWarmup.reset();
    FlxG.stage = new Stage(new Context3D());

    final late = new Shader();
    ShaderWarmup.track(late);
    check(ShaderWarmup.endLoading() == 0, 'tracking outside a loading phase is ignored');

    ShaderWarmup.beginLoading();
    final queued = new Shader();
    ShaderWarmup.track(queued);
    ShaderWarmup.track(queued);
    ShaderWarmup.track(null);
    check(ShaderWarmup.endLoading() == 1, 'queued shader compiled once');
    check(queued.program != null, 'queued shader has a program');

    final afterLoad = new Shader();
    afterLoad.glFragmentSource = 'void main() { gl_FragColor = vec4(0.5); }';
    ShaderWarmup.track(afterLoad);
    check(ShaderWarmup.endLoading() == 0, 'loading phase ended');
    check(afterLoad.program == null, 'late tracking does nothing');
  }

  /** A `FlxFixedShader` with `save = false` keeps its program per instance. */
  static function respectsNonSharingShaders():Void
  {
    ShaderWarmup.reset();
    FlxG.stage = new Stage(new Context3D());

    final first = new NotSavedShader();
    final second = new NotSavedShader();
    check(ShaderWarmup.warm(first), 'non-saving shader warms');
    check(ShaderWarmup.warm(second), 'twin non-saving shader warms');
    check(second.program != null, 'twin compiled its own program');
    check(ShaderWarmup.compiled == 2, 'both compiles counted');
  }
}

/** Models `FlxFixedShader(save = false)`: no shared source cache entry. */
class NotSavedShader extends FlxFixedShader
{
  public function new()
  {
    super();
    save = false;
  }
}
