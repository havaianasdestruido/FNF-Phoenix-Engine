import backend.ClientPrefs;
import data.StageData.StageFile;
import flixel.FlxG;
import openfl.display.Shader;
import openfl.display.Stage;
import openfl.display3D.Context3D;
import play.BaseStage;
import play.PlayState;
import play.helpers.PlayStateShaders;
import shaders.ShaderWarmup;

/**
 * Contract tests for `play.helpers.PlayStateShaders`.
 *
 * The helper decides *what* a song warms up (the song-wide `Pulse` shader, the
 * stage's instances, the stage JSON names and the runtime shaders scripts
 * queued while loading). It runs here against stubs of `PlayState`, the stage
 * base and the shader registry, driven by the real `shaders.ShaderWarmup`
 * against stubbed OpenFL types — see `tests/haxe/run-shader-warmup.sh`.
 */
class PlayStateShadersSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function main():Void
  {
    warmsEveryDeclaration();
    dropsTheQueueWhenShadersAreOff();
  }

  /** One compile per distinct GLSL, whatever declared it. */
  static function warmsEveryDeclaration():Void
  {
    ShaderWarmup.reset();
    FlxG.stage = new Stage(new Context3D());
    ClientPrefs.shaders = true;

    final state = new PlayState();
    state.stages.push(new ShaderStage());
    state.runtimeShaders.set('modShader', ['void main() {}', 'void main() {}']);

    final stageFile:StageFile = {shaders: ['rain', 'Rain.frag', '', 'modShader', 'notARealShader']};

    PlayStateShaders.beginLoad();
    final warmed = PlayStateShaders.warmUp(state, stageFile);

    // screenshader + stage instance + rain + mod shader; the duplicate
    // declaration and the empty entry add nothing, and unknown names only warn.
    check(warmed == 4, 'expected 4 warmed shaders, got ' + warmed);

    // Every stub shader shares one GLSL source, so the driver is asked once and
    // the rest are answered by the program cache.
    check(ShaderWarmup.compiled == 1, 'expected one driver compile, got ' + ShaderWarmup.compiled);
    check(ShaderWarmup.reused == warmed - 1, 'expected cache hits for the rest');

    // The loading phase is over: a late runtime shader is not queued.
    ShaderWarmup.track(new Shader());
    check(ShaderWarmup.endLoading() == 0, 'tracking stops after warm-up');
  }

  /** With shaders disabled nothing may be compiled and the queue is dropped. */
  static function dropsTheQueueWhenShadersAreOff():Void
  {
    ShaderWarmup.reset();
    FlxG.stage = new Stage(new Context3D());
    ClientPrefs.shaders = false;

    final state = new PlayState();
    state.stages.push(new ShaderStage());

    PlayStateShaders.beginLoad();
    ShaderWarmup.track(new Shader());
    check(PlayStateShaders.warmUp(state, {shaders: ['rain']}) == 0, 'disabled shaders warm nothing');
    check(ShaderWarmup.compiled == 0, 'nothing compiled');
    check(ShaderWarmup.endLoading() == 0, 'queued shaders dropped');

    ClientPrefs.shaders = true;
  }
}

/** A stage class that renders with one shader instance. */
class ShaderStage extends BaseStage
{
  override function declareShaders():Array<Shader>
  {
    return [new Shader()];
  }
}
