import shaders.ShaderWarmupPlan;

/**
 * Contract tests for `shaders.ShaderWarmupPlan`.
 *
 * The plan module is Flixel-free on purpose, so the rules that turn a stage's
 * `"shaders"` JSON array into the list `shaders.ShaderWarmup` compiles can be
 * checked in the Haxe interpreter, without the game's haxelibs.
 *
 *     bash tests/haxe/run-shader-warmup.sh
 */
class ShaderWarmupPlanSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equals(actual:String, expected:String, label:String):Void
  {
    check(actual == expected, label + ': expected "' + expected + '", got "' + actual + '"');
  }

  static function main():Void
  {
    normalizesNames();
    keepsFileNameCase();
    keepsDeclaredSpelling();
    dropsUnusableEntries();
    honoursSkipList();
    handlesMissingArrays();
  }

  /** Case, whitespace, folders and shader extensions never reach the registry. */
  static function normalizesNames():Void
  {
    equals(ShaderWarmupPlan.normalizeName('rain'), 'rain', 'plain name');
    equals(ShaderWarmupPlan.normalizeName('  Rain  '), 'rain', 'trimmed and lowercased');
    equals(ShaderWarmupPlan.normalizeName('Rain.frag'), 'rain', '.frag stripped');
    equals(ShaderWarmupPlan.normalizeName('Rain.VERT'), 'rain', '.vert stripped');
    equals(ShaderWarmupPlan.normalizeName('rain.glsl'), 'rain', '.glsl stripped');
    equals(ShaderWarmupPlan.normalizeName('mods/mymod/shaders/Rain.frag'), 'rain', 'path stripped');
    equals(ShaderWarmupPlan.normalizeName('mods\\mymod\\shaders\\Rain.frag'), 'rain', 'windows path stripped');
    equals(ShaderWarmupPlan.normalizeName(null), '', 'null name');
    equals(ShaderWarmupPlan.normalizeName('   '), '', 'blank name');
    equals(ShaderWarmupPlan.normalizeName('rain.frag/'), '', 'name with only a folder');
  }

  /** Mod shader files are looked up with their case intact, minus the folder. */
  static function keepsFileNameCase():Void
  {
    equals(ShaderWarmupPlan.runtimeName(' MyEffect.frag '), 'MyEffect', 'case kept, extension dropped');
    equals(ShaderWarmupPlan.runtimeName('mods/mymod/shaders/MyEffect.frag'), 'MyEffect', 'path dropped');
    equals(ShaderWarmupPlan.runtimeName('mods\\mymod\\MyEffect.vert'), 'MyEffect', 'windows path dropped');
    equals(ShaderWarmupPlan.runtimeName(null), '', 'null name');
    equals(ShaderWarmupPlan.runtimeName('   '), '', 'blank name');
  }

  /**
   * Declared names stay as written, so a case-sensitive filesystem can still
   * find a mod's `MyEffect.frag`; only comparisons are normalized.
   */
  static function keepsDeclaredSpelling():Void
  {
    final names = ShaderWarmupPlan.declaredNames([' Rain ', 'MyEffect.frag']);
    check(names.length == 2, 'both names kept');
    equals(names[0], 'Rain', 'trimmed, spelling kept');
    equals(names[1], 'MyEffect.frag', 'raw name kept');
  }

  /** Blank and duplicate declarations collapse to one entry, in order. */
  static function dropsUnusableEntries():Void
  {
    final names = ShaderWarmupPlan.declaredNames([
      'rain',
      ' Rain ',
      'rain.frag',
      null,
      '',
      '   ',
      'glitch',
      'GLITCH.frag'
    ]);
    check(names.length == 2, 'duplicates dropped, got ' + names.length);
    equals(names[0], 'rain', 'first duplicate wins');
    equals(names[1], 'glitch', 'second name kept');
  }

  /** The skip list is compared normalized, so it can come from anywhere. */
  static function honoursSkipList():Void
  {
    final names = ShaderWarmupPlan.declaredNames(['rain', 'glitch', 'bloom'], ['Rain.frag', 'BLOOM']);
    check(names.length == 1, 'skipped names removed');
    equals(names[0], 'glitch', 'remaining name');
  }

  /** A stage file without a `shaders` key must not blow up. */
  static function handlesMissingArrays():Void
  {
    final names = ShaderWarmupPlan.declaredNames(null);
    check(names.length == 0, 'null array');
    check(ShaderWarmupPlan.declaredNames([]).length == 0, 'empty array');
  }
}
