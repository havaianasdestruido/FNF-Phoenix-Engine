import shaders.BrightnessContrastEffect;
import shaders.BrightnessContrastShader;
import shaders.CRTEffect;
import shaders.CRTShader;
import shaders.EffectTicker;
import shaders.MosaicEffect;
import shaders.MosaicShader;
import shaders.OldTVEffect;
import shaders.OldTVShader;
import shaders.RippleEffect;
import shaders.RippleShader;
import shaders.SilhouetteEffect;
import shaders.SilhouetteShader;
import shaders.TVStaticEffect;
import shaders.TVStaticShader;
import shaders.VCRBorderEffect;
import shaders.VCRBorderShader;
import shaders.VCRFuzzEffect;
import shaders.VCRFuzzShader;

import flixel.FlxG;
import play.PlayState;

using StringTools;

/**
 * Contract tests for the Mario Madness shader ports (TODO.md §23.2 "Shaders"):
 * `CRT`, `OldTV`, `TVStatic`, `Ripple`, `Silhouette`, `Mosaic`,
 * `BrightnessContrast`, `VCRBorder` and `VCRFuzz`, plus `shaders.EffectTicker`.
 *
 * Three things are checked, in this order:
 *
 * 1. the GLSL itself, read back from `source/shaders/*.hx`: `#pragma header`,
 *    `void main()`, and none of the constructs that break the targets this engine
 *    ships on (unsigned integers for WebGL1, `texture()` for GLSL 120, `0.`
 *    literals for strict GLSL ES, non-constant loop bounds, a base class that
 *    would skip the OpenGL ES rewrite);
 * 2. that every `uniform` the GLSL declares is initialised by the shader's
 *    constructor with an array of the right length - an uninitialised uniform
 *    silently renders as 0, which for `uBrightness` or `uBlocksize` means a black
 *    screen. The uniform *names* are checked from the other side by the runner:
 *    it generates the `FlxFixedShader` stub from those same declarations, so a
 *    Haxe field the GLSL never declares does not compile at all;
 * 3. the effect wrappers: defaults, the write-through to the uniforms, the
 *    validation that keeps a bad script value from reaching the driver, and the
 *    `EffectTicker` routing that makes the animated ones work outside a song.
 *
 * Registration is checked too: `shaders.ShaderWarmupRegistry` must know each
 * shader by name (so a stage can precompile it from its JSON) and
 * `psychlua.callbacks.EffectCallbacks` must expose each effect *inside* its
 * `if (ClientPrefs.shaders)` block, which is what the shaders toggle gates.
 *
 * Runs against stubs (`tests/haxe/stubs/retro-shaders/` plus the generated
 * `FlxFixedShader`); see `tests/haxe/run-retro-shaders.sh`.
 */
class RetroShadersSpec
{
  /** Shader source file -> the effect class that wraps it, as text names. */
  static final SHADERS:Array<String> = [
    'CRTShader', 'OldTVShader', 'TVStaticShader', 'RippleShader', 'SilhouetteShader', 'MosaicShader', 'BrightnessContrastShader', 'VCRBorderShader',
    'VCRFuzzShader'
  ];

  /** Built-in name a stage can declare in its JSON -> shader class. */
  static final REGISTRY_NAMES:Array<Array<String>> = [
    ['crt', 'CRTShader'],
    ['oldtv', 'OldTVShader'],
    ['tvstatic', 'TVStaticShader'],
    ['ripple', 'RippleShader'],
    ['silhouette', 'SilhouetteShader'],
    ['mosaic', 'MosaicShader'],
    ['pixelblur', 'MosaicShader'],
    ['smwpixelblur', 'MosaicShader'],
    ['brightnesscontrast', 'BrightnessContrastShader'],
    ['vcrborder', 'VCRBorderShader'],
    ['vcrfuzz', 'VCRFuzzShader'],
    ['vcrmario85', 'VCRFuzzShader']
  ];

  /** Script-facing callback -> the effect it must construct. */
  static final CALLBACKS:Array<Array<String>> = [
    ['addCRTEffect', 'CRTEffect'],
    ['addOldTVEffect', 'OldTVEffect'],
    ['addTVStaticEffect', 'TVStaticEffect'],
    ['addRippleEffect', 'RippleEffect'],
    ['addSilhouetteEffect', 'SilhouetteEffect'],
    ['addMosaicEffect', 'MosaicEffect'],
    ['addSMWPixelBlurEffect', 'MosaicEffect'],
    ['addBrightnessContrastEffect', 'BrightnessContrastEffect'],
    ['addVCRBorderEffect', 'VCRBorderEffect'],
    ['addVCRFuzzEffect', 'VCRFuzzEffect']
  ];

  static function main():Void
  {
    glslIsPortable();
    uniformsAreInitialized();
    tickerRouting();
    effectWiring();
    callbackShapes();
    registrationIsComplete();
    trace('retro shaders: GLSL portability, uniform wiring, effect validation and registration OK');
  }

  /* ------------------------------------------------------------------ *
   * 1. The GLSL sources
   * ------------------------------------------------------------------ */

  static function glslIsPortable():Void
  {
    for (name in SHADERS)
    {
      final source:String = shaderSource(name);
      final glsl:String = glslOf(source);

      check(glsl.length > 0, '$name: no @:glFragmentSource block found');
      check(glsl.indexOf('#pragma header') >= 0, '$name: missing #pragma header');
      check(glsl.indexOf('void main()') >= 0, '$name: missing void main()');
      check(glsl.indexOf('gl_FragColor') >= 0, '$name: never writes gl_FragColor');

      // The GLES rewrite lives in backend.FlxFixedShader; extending plain
      // FlxShader would ship GLSL that Android and WebGL2 have to reject.
      check(source.indexOf('extends FlxFixedShader') >= 0, '$name: must extend backend.FlxFixedShader for OpenGL ES');
      check(source.indexOf('import backend.FlxFixedShader;') >= 0, '$name: must import backend.FlxFixedShader');

      // Without comments: the prose is allowed to say "0.5x" or "texture()".
      final code:String = stripComments(glsl);

      // uvec and the U suffix do not exist in GLSL ES 1.00 (WebGL1/html5).
      check(code.indexOf('uvec') < 0, '$name: uvec is unavailable on GLSL ES 1.00');
      check(!~/[0-9]+[uU]\b/.match(code), '$name: unsigned integer literals are unavailable on GLSL ES 1.00');

      // texture() is GLSL 1.30+; FlxFixedShader rewrites texture2D for GLES and
      // flixel_texture2D also applies the sprite colour transform.
      final bare:String = code.split('flixel_texture2D').join('#');
      check(bare.indexOf('texture(') < 0, '$name: use flixel_texture2D()/texture2D(), not texture()');

      // "1." and "0." are the literals that broke the upstream sources on strict
      // drivers; a float literal always needs a digit on both sides of the point.
      check(!hasTruncatedFloatLiteral(code), '$name: float literal without fractional digits (write 1.0, not 1.)');
      check(!hasLeadingDotLiteral(code), '$name: float literal without a leading digit (write 0.5, not .5)');

      // Loops need a constant bound and an int counter on GLSL ES 1.00.
      for (line in code.split('\n'))
      {
        final trimmed:String = line.trim();
        if (trimmed.indexOf('for (') != 0 && trimmed.indexOf('for(') != 0) continue;
        check(~/^for\s*\(\s*int\s+\w+\s*=\s*-?[0-9]+\s*;\s*\w+\s*(<|<=)\s*([0-9]+|\w+)\s*;\s*\w+\+\+\s*\)/.match(trimmed),
          '$name: loop is not a constant-bound int loop: $trimmed');
      }
    }
  }

  /* ------------------------------------------------------------------ *
   * 2. Uniform initialization
   * ------------------------------------------------------------------ */

  static function uniformsAreInitialized():Void
  {
    for (name in SHADERS)
    {
      final declared:Array<Array<String>> = uniformsOf(glslOf(shaderSource(name)));
      check(declared.length > 0, '$name declares no uniforms');

      final shader:Dynamic = createShader(name);
      for (uniform in declared)
      {
        final type:String = uniform[0];
        final field:String = uniform[1];
        final expected:Int = componentsOf(type);

        final value:Dynamic = Reflect.field(shader, field);
        check(value != null, '$name: uniform $field has no generated field (stub/GLSL mismatch)');

        final array:Array<Dynamic> = Reflect.field(value, 'value');
        check(array != null, '$name: $type $field is never initialized, so it renders as 0');
        check(array.length == expected, '$name: $field needs $expected component(s), got ' + array.length);

        for (component in array)
        {
          check(component != null, '$name: $field has a null component');
          // Bool uniforms have nothing to NaN-check.
          if (Std.isOfType(component, Float) || Std.isOfType(component, Int))
            check(!Math.isNaN(Std.parseFloat(Std.string(component))), '$name: $field has a NaN component');
        }
      }
    }
  }

  static function createShader(name:String):Dynamic
  {
    return switch (name)
    {
      case 'CRTShader': new CRTShader();
      case 'OldTVShader': new OldTVShader();
      case 'TVStaticShader': new TVStaticShader();
      case 'RippleShader': new RippleShader();
      case 'SilhouetteShader': new SilhouetteShader();
      case 'MosaicShader': new MosaicShader();
      case 'BrightnessContrastShader': new BrightnessContrastShader();
      case 'VCRBorderShader': new VCRBorderShader();
      case 'VCRFuzzShader': new VCRFuzzShader();
      default: throw 'unknown shader $name';
    }
  }

  /* ------------------------------------------------------------------ *
   * 3. EffectTicker routing
   * ------------------------------------------------------------------ */

  static function tickerRouting():Void
  {
    // No song: the callback goes on postUpdate, not on a PlayState list.
    PlayState.instance = null;
    FlxG.state = null;

    var ticks:Int = 0;
    var lastElapsed:Float = -1.0;
    final outside:Float->Void = function(elapsed:Float)
    {
      ticks++;
      lastElapsed = elapsed;
    };
    EffectTicker.add(outside);
    check(EffectTicker.count() == 1, 'an out-of-song effect must register on the ticker, got ' + EffectTicker.count());

    FlxG.elapsed = 0.25;
    FlxG.signals.postUpdate.dispatch();
    check(ticks == 1, 'postUpdate must tick the callback once');
    check(lastElapsed == 0.25, 'the callback must receive FlxG.elapsed');

    // Removing it stops the ticks without detaching the signal itself.
    EffectTicker.remove(outside);
    check(EffectTicker.count() == 0, 'remove() must detach the callback');
    FlxG.signals.postUpdate.dispatch();
    check(ticks == 1, 'a removed callback must not tick again');

    // A live song reuses PlayState.shaderUpdates.
    final game:PlayState = new PlayState();
    PlayState.instance = game;
    FlxG.state = game;

    var songTicks:Int = 0;
    EffectTicker.add(function(elapsed:Float) songTicks++);
    check(EffectTicker.count() == 0, 'a song effect must not use the out-of-song path');
    check(game.shaderUpdates.length == 1, 'a song effect must land in PlayState.shaderUpdates');
    game.shaderUpdates[0](0.5);
    check(songTicks == 1, 'shaderUpdates must drive the callback');

    // PlayState.destroy() never nulls `instance`, so a leftover instance must not
    // swallow callbacks created from a menu.
    FlxG.state = null;
    EffectTicker.add(outside);
    check(EffectTicker.count() == 1, 'a stale PlayState.instance must not capture the callback');
    check(game.shaderUpdates.length == 1, 'the stale instance list must stay untouched');

    // Leaving the state drops what the previous screen registered.
    EffectTicker.remove(outside);
    EffectTicker.add(outside);
    check(EffectTicker.count() == 1, 'sanity: the callback is registered again');
    FlxG.signals.preStateSwitch.dispatch();
    check(EffectTicker.count() == 0, 'a state switch must clear out-of-song callbacks');
    ticks = 0;
    FlxG.signals.postUpdate.dispatch();
    check(ticks == 0, 'nothing may tick after the state switch cleared the list');

    PlayState.instance = null;
    FlxG.state = null;
    FlxG.elapsed = 0.0;
  }

  /* ------------------------------------------------------------------ *
   * 4. Effect wrappers
   * ------------------------------------------------------------------ */

  static function effectWiring():Void
  {
    PlayState.instance = null;
    FlxG.state = null;

    // A title-screen effect: it ticks from postUpdate.
    final titleStatic:TVStaticEffect = new TVStaticEffect();
    check(titleStatic.shader.uStrength.value[0] == 1.0, 'TVStatic default strength');
    check(titleStatic.shader.uMinStrength.value[0] == 0.3, 'TVStatic default floor');
    check(titleStatic.shader.uMaxStrength.value[0] == 0.8, 'TVStatic default ceiling');
    check(titleStatic.shader.uSpeed.value[0] == 20.0, 'TVStatic default speed');
    check(EffectTicker.count() == 1, 'the title-screen effect must be ticking');
    FlxG.elapsed = 0.5;
    FlxG.signals.postUpdate.dispatch();
    check(titleStatic.time == 0.5, 'postUpdate must advance uTime, got ' + titleStatic.time);
    titleStatic.strength = 2.0;
    titleStatic.minStrength = 0.9;
    titleStatic.maxStrength = 0.1;
    check(titleStatic.shader.uStrength.value[0] == 2.0, 'strength write-through');
    check(titleStatic.shader.uMinStrength.value[0] == 0.9, 'minStrength write-through');
    check(titleStatic.shader.uMaxStrength.value[0] == 0.1, 'maxStrength write-through');

    // Song effects: they tick from PlayState.shaderUpdates.
    final game:PlayState = new PlayState();
    PlayState.instance = game;
    FlxG.state = game;
    final tv:OldTVEffect = new OldTVEffect();
    final water:RippleEffect = new RippleEffect();
    final tape:VCRFuzzEffect = new VCRFuzzEffect();
    check(game.shaderUpdates.length == 3, 'three animated effects must register on the song, got ' + game.shaderUpdates.length);
    check(EffectTicker.count() == 1, 'the song effects must not double-register on the ticker');
    for (update in game.shaderUpdates)
      update(0.25);
    check(tv.time == 0.25, 'OldTV uTime must advance');
    check(water.time == 0.25, 'Ripple uTime must advance');
    check(tape.time == 0.25, 'VCRFuzz uTime must advance');

    // OldTV defaults and clamps.
    check(tv.shader.uStatic.value[0] == 0.05, 'OldTV default static');
    check(tv.shader.uDamage.value[0] == 1.0, 'OldTV default damage');
    check(tv.shader.uBlur.value[0] == 0.0, 'OldTV must default to the cheap path');
    check(tv.shader.uBar.value[0] == true, 'OldTV default bar');
    check(tv.shader.uBarOffset.value[0] == 0.01, 'OldTV default bar offset');
    tv.blur = -3.0;
    check(tv.shader.uBlur.value[0] == 0.0, 'a negative blur radius must clamp to 0');
    tv.blur = 4.0;
    check(tv.shader.uBlur.value[0] == 4.0, 'blur write-through');
    tv.bar = false;
    check(tv.shader.uBar.value[0] == false, 'bar write-through');
    tv.staticAmount = -1.0;
    check(tv.shader.uStatic.value[0] == 0.0, 'a negative static amount must clamp to 0');
    tv.damage = 0.25;
    check(tv.shader.uDamage.value[0] == 0.25, 'damage write-through');

    // Ripple defaults and clamps.
    check(water.shader.uStrength.value[0] == 10.0, 'Ripple default strength');
    check(water.shader.uSpeed.value[0] == 0.5, 'Ripple default speed');
    check(water.shader.uScale.value[0] == 1.0, 'Ripple default scale');
    water.scale = 0.0;
    check(water.shader.uScale.value[0] > 0.0, 'a zero noise scale would freeze the ripple');
    water.scale = 2.0;
    check(water.shader.uScale.value[0] == 2.0, 'scale write-through');
    water.strength = 25.0;
    check(water.shader.uStrength.value[0] == 25.0, 'strength write-through');

    // VCRFuzz defaults and clamps.
    check(tape.shader.uFuzz.value[0] == 1.0, 'VCRFuzz default fuzz');
    check(near(tape.shader.uSplit.value[0], 0.003), 'VCRFuzz default split');
    check(near(tape.shader.uScanline.value[0], 0.04), 'VCRFuzz default scanline');
    check(tape.shader.uScanlineFrequency.value[0] == 800.0, 'VCRFuzz default scanline frequency');
    tape.split = -1.0;
    check(tape.shader.uSplit.value[0] == 0.0, 'a negative channel split must clamp to 0');
    tape.fuzz = 3.0;
    check(tape.shader.uFuzz.value[0] == 3.0, 'fuzz write-through');

    // CRT: no time, all validation.
    final crt:CRTEffect = new CRTEffect();
    check(crt.shader.uWarp.value.length == 2, 'CRT warp is a vec2');
    check(near(crt.shader.uWarp.value[0], 1.0 / 32.0), 'CRT default warp x');
    check(near(crt.shader.uWarp.value[1], 1.0 / 24.0), 'CRT default warp y');
    check(crt.shader.uHardScan.value[0] == -8.0, 'CRT default scanline hardness');
    check(crt.shader.uHardPix.value[0] == -2.0, 'CRT default pixel hardness');
    check(crt.shader.uMask.value[0] == 1.0, 'CRT default mask');
    check(crt.shader.uMaskDark.value[0] == 0.5, 'CRT default dark phosphor');
    check(crt.shader.uMaskLight.value[0] == 1.5, 'CRT default light phosphor');
    check(crt.shader.uVignette.value[0] == 0.25, 'CRT default vignette');
    check(crt.shader.uResolutionScale.value[0] == 0.5, 'CRT default resolution scale');
    crt.curve = 0.0;
    check(crt.shader.uWarp.value[0] == 0.0 && crt.shader.uWarp.value[1] == 0.0, 'curve 0 must be a flat screen');
    crt.curve = -2.0;
    check(crt.shader.uWarp.value[0] == 0.0, 'a negative curve must clamp to flat instead of folding the screen');
    crt.curve = 2.0;
    check(near(crt.shader.uWarp.value[0], 2.0 / 32.0) && near(crt.shader.uWarp.value[1], 2.0 / 24.0), 'curve scales both axes');
    crt.scanlineHardness = 8.0;
    check(crt.shader.uHardScan.value[0] <= -0.5, 'a positive hardness would overflow exp2(), got ' + crt.shader.uHardScan.value[0]);
    crt.scanlineHardness = -16.0;
    check(crt.shader.uHardScan.value[0] == -16.0, 'hardness write-through');
    crt.scanlineHardness = Math.NaN;
    check(crt.shader.uHardScan.value[0] == -8.0, 'NaN hardness must fall back to the default');
    crt.pixelHardness = -4.0;
    check(crt.shader.uHardPix.value[0] == -4.0, 'pixel hardness write-through');
    crt.resolutionScale = -1.0;
    check(crt.shader.uResolutionScale.value[0] == 0.0, 'a negative resolution scale must clamp to 0');
    crt.vignette = 0.75;
    check(crt.shader.uVignette.value[0] == 0.75, 'vignette write-through');
    crt.mask = 0.0;
    check(crt.shader.uMask.value[0] == 0.0, 'mask write-through');

    // Silhouette: colour conversion and amount clamp.
    final silhouette:SilhouetteEffect = new SilhouetteEffect();
    check(silhouette.shader.uColor.value.length == 3, 'silhouette colour is a vec3');
    check(silhouette.shader.uColor.value[0] == 0.0, 'silhouette defaults to black');
    check(silhouette.shader.uAmount.value[0] == 1.0, 'silhouette defaults to a full silhouette');
    final orange:SilhouetteEffect = new SilhouetteEffect(0xFFFF8000, 0.5);
    check(near(orange.shader.uColor.value[0], 1.0), 'red channel of 0xFFFF8000');
    check(near(orange.shader.uColor.value[1], 128.0 / 255.0), 'green channel of 0xFFFF8000');
    check(orange.shader.uColor.value[2] == 0.0, 'blue channel of 0xFFFF8000');
    check(orange.shader.uAmount.value[0] == 0.5, 'amount write-through');
    orange.amount = 4.0;
    check(orange.shader.uAmount.value[0] == 1.0, 'amount must clamp to 1');
    orange.amount = -4.0;
    check(orange.shader.uAmount.value[0] == 0.0, 'amount must clamp to 0');
    orange.color = 0xFF0000FF;
    check(orange.shader.uColor.value[2] == 1.0 && orange.shader.uColor.value[0] == 0.0, 'colour write-through');

    // Mosaic: block size clamping, both axes, and the SMWPixelBlur alias API.
    final mosaic:MosaicEffect = new MosaicEffect();
    check(mosaic.shader.uBlocksize.value.length == 2, 'mosaic block size is a vec2');
    check(mosaic.shader.uBlocksize.value[0] == 1.0, 'mosaic defaults to no pixelation');
    final coarse:MosaicEffect = new MosaicEffect(8);
    check(coarse.shader.uBlocksize.value[0] == 8.0 && coarse.shader.uBlocksize.value[1] == 8.0, 'one block size sets both axes');
    final wide:MosaicEffect = new MosaicEffect(16, 4);
    check(wide.shader.uBlocksize.value[0] == 16.0 && wide.shader.uBlocksize.value[1] == 4.0, 'per-axis block sizes');
    wide.setStrength(0, 0);
    check(wide.shader.uBlocksize.value[0] >= 1.0 && wide.shader.uBlocksize.value[1] >= 1.0,
      'a zero block size divides by zero and blacked out the screen upstream');
    wide.setStrength(Math.NaN);
    check(wide.shader.uBlocksize.value[0] == 1.0 && wide.shader.uBlocksize.value[1] == 1.0, 'NaN block size must fall back to 1');
    wide.setStrength(12);
    check(wide.shader.uBlocksize.value[1] == 12.0, 'setStrength with one argument sets both axes');
    wide.blockSizeX = 3.0;
    check(wide.shader.uBlocksize.value[0] == 3.0 && wide.shader.uBlocksize.value[1] == 12.0, 'blockSizeX only moves its own axis');

    // Brightness/contrast: the dimmer, with its clamps.
    final dim:BrightnessContrastEffect = new BrightnessContrastEffect();
    check(dim.shader.uBrightness.value[0] == 1.0 && dim.shader.uContrast.value[0] == 1.0, 'brightness/contrast default to a no-op');
    dim.brightness = 0.6;
    check(near(dim.shader.uBrightness.value[0], 0.6), 'brightness write-through');
    dim.brightness = -2.0;
    check(dim.shader.uBrightness.value[0] == 0.0, 'a negative brightness must clamp to black, not invert');
    dim.brightness = Math.NaN;
    check(dim.shader.uBrightness.value[0] == 1.0, 'NaN brightness must fall back to 1');
    dim.contrast = 2.0;
    check(dim.shader.uContrast.value[0] == 2.0, 'contrast write-through');
    dim.contrast = -1.0;
    check(dim.shader.uContrast.value[0] == 0.0, 'a negative contrast must clamp to flat grey');

    // VCR border: the frame without the glitch.
    final border:VCRBorderEffect = new VCRBorderEffect();
    check(border.shader.uCurve.value[0] == 1.0, 'border default curve');
    check(border.shader.uVignette.value[0] == 1.0, 'border default vignette');
    check(border.shader.uBorder.value[0] == true, 'border defaults to a black bezel');
    border.curve = -1.0;
    check(border.shader.uCurve.value[0] == 0.0, 'a negative curve must clamp to a flat screen');
    border.curve = 0.5;
    check(border.shader.uCurve.value[0] == 0.5, 'curve write-through');
    border.border = false;
    check(border.shader.uBorder.value[0] == false, 'border write-through');
    border.vignette = 0.0;
    check(border.shader.uVignette.value[0] == 0.0, 'vignette write-through');

    // Leaving the screen drops the title-screen effect but not the song ones.
    FlxG.signals.preStateSwitch.dispatch();
    check(EffectTicker.count() == 0, 'the title-screen effect must be dropped on a state switch');
    check(game.shaderUpdates.length == 3, 'song effects stay with their state');

    PlayState.instance = null;
    FlxG.state = null;
    FlxG.elapsed = 0.0;
  }

  /* ------------------------------------------------------------------ *
   * 5. Registration
   * ------------------------------------------------------------------ */

  static function callbackShapes()
  {
    // The documented Lua signature has to match what EffectCallbacks actually
    // registers, since docs/SHADERS.md and the generated API reference are both
    // read against that file.
    var source:String = read('source/psychlua/callbacks/EffectCallbacks.hx');
    var expected = [
      'addCRTEffect' => ['camera:String', 'curve:Float', 'scanlineHardness:Float', 'pixelHardness:Float', 'mask:Float', 'vignette:Float',
        'resolutionScale:Float'],
      'addOldTVEffect' => ['camera:String', 'staticAmount:Float', 'damage:Float', 'blur:Float', 'bar:Bool', 'barOffset:Float'],
      'addTVStaticEffect' => ['camera:String', 'strength:Float', 'minStrength:Float', 'maxStrength:Float', 'speed:Float'],
      'addRippleEffect' => ['camera:String', 'strength:Float', 'speed:Float', 'scale:Float'],
      'addSilhouetteEffect' => ['camera:String', 'color:Dynamic', 'amount:Float'],
      'addMosaicEffect' => ['camera:String', 'blockSize:Float', 'blockSizeY:Float'],
      'addSMWPixelBlurEffect' => ['camera:String', 'strengthX:Float', 'strengthY:Float'],
      'addBrightnessContrastEffect' => ['camera:String', 'brightness:Float', 'contrast:Float'],
      'addVCRBorderEffect' => ['camera:String', 'curve:Float', 'vignette:Float', 'border:Bool'],
      'addVCRFuzzEffect' => ['camera:String', 'fuzz:Float', 'split:Float', 'scanline:Float', 'scanlineFrequency:Float']
    ];

    for (name in expected.keys())
    {
      var signature:String = registrationArguments(source, name);
      for (arg in expected[name])
      {
        check(signature.indexOf(arg) >= 0, 'EffectCallbacks: $name is missing the documented argument "$arg" (has: $signature)');
      }
    }
  }

  /** The argument list of a `registerFunction("name", function(...) {` call. */
  static function registrationArguments(source:String, name:String):String
  {
    var open:Int = source.indexOf('registerFunction("$name"');
    if (open < 0) return '';
    var fn:Int = source.indexOf('function(', open);
    if (fn < 0) return '';
    var close:Int = source.indexOf(')', fn);
    return close < 0 ? '' : source.substring(fn + 'function('.length, close);
  }

  static function registrationIsComplete():Void
  {
    final registry:String = read('source/shaders/ShaderWarmupRegistry.hx');
    for (entry in REGISTRY_NAMES)
    {
      check(registry.indexOf("'" + entry[0] + "'") >= 0, 'ShaderWarmupRegistry is missing the name "${entry[0]}"');
      check(registry.indexOf('new ' + entry[1] + '()') >= 0, 'ShaderWarmupRegistry never creates ${entry[1]}');
      check(registry.indexOf('import shaders.' + entry[1] + ';') >= 0, 'ShaderWarmupRegistry does not import ${entry[1]}');
    }

    final callbacks:String = read('source/psychlua/callbacks/EffectCallbacks.hx');
    // Everything a script can call lives inside this block, which is the shaders
    // toggle: with `ClientPrefs.shaders` off none of it is registered at all.
    final guarded:String = blockAfter(callbacks, 'if (ClientPrefs.shaders) {');
    check(guarded != null, 'EffectCallbacks lost its ClientPrefs.shaders guard');

    for (entry in CALLBACKS)
    {
      final name:String = entry[0];
      check(callbacks.indexOf('import shaders.' + entry[1] + ';') >= 0, 'EffectCallbacks does not import ${entry[1]}');
      check(guarded.indexOf('registerFunction("$name"') >= 0, '$name is not registered inside the ClientPrefs.shaders guard');
      check(guarded.indexOf('new ${entry[1]}(') >= 0, '$name does not construct ${entry[1]}');
      // The generated Lua/Python API reference takes each description from the
      // `//` block directly above the registration
      // (website/scripts/generate-script-api.mjs), so a callback without one
      // ships with "The source does not provide a description".
      final doc:String = commentAbove(callbacks, 'registerFunction("$name"');
      check(doc != null && doc.length > 0, '$name has no // description for the generated API reference');
    }
  }

  /* ------------------------------------------------------------------ *
   * Helpers
   * ------------------------------------------------------------------ */

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function near(value:Float, expected:Float):Bool
  {
    return Math.abs(value - expected) < 0.0001;
  }

  static function read(path:String):String
  {
    try
    {
      return sys.io.File.getContent(path);
    }
    catch (e:Any)
    {
      throw 'cannot read $path (run this from the repository root): $e';
    }
  }

  static function shaderSource(name:String):String
  {
    return read('source/shaders/$name.hx');
  }

  /** The GLSL inside the `@:glFragmentSource('...')` metadata. */
  static function glslOf(source:String):String
  {
    final begin:Int = source.indexOf("@:glFragmentSource('");
    if (begin < 0) return '';
    final end:Int = source.indexOf("')", begin);
    if (end < 0) return '';
    return source.substring(begin + "@:glFragmentSource('".length, end);
  }

  static function stripComments(glsl:String):String
  {
    final lines:Array<String> = glsl.split('\n');
    for (i in 0...lines.length)
    {
      final marker:Int = lines[i].indexOf('//');
      if (marker >= 0) lines[i] = lines[i].substr(0, marker);
    }
    return lines.join('\n');
  }

  /**
   * Whether the code contains a float literal with no leading digit (`.5`),
   * which GLSL ES accepts on some drivers and rejects on others. Swizzle accesses
   * (`uv.x`) and version-style text are not literals, so the character before the
   * point decides.
   */
  static function hasLeadingDotLiteral(code:String):Bool
  {
    for (i in 0...code.length)
    {
      if (code.charAt(i) != '.') continue;
      if (!isDigit(charAtOr(code, i + 1))) continue;
      final before:String = charAtOr(code, i - 1);
      if (!isDigit(before) && !isIdentifierChar(before) && before != '.') return true;
    }
    return false;
  }

  /**
   * Whether the code contains a number literal with nothing after its decimal
   * point (`1.`, `0.`), which GLSL ES rejects. Swizzles on numbered variables
   * (`p3.x`) are not literals, so only a digit run that starts a token counts.
   */
  static function hasTruncatedFloatLiteral(code:String):Bool
  {
    var i:Int = 0;
    while (i < code.length)
    {
      if (!isDigit(code.charAt(i)) || isIdentifierChar(charAtOr(code, i - 1)))
      {
        i++;
        continue;
      }

      // A standalone number: consume its digits, then look at the point.
      var end:Int = i;
      while (end < code.length && isDigit(code.charAt(end)))
        end++;
      if (charAtOr(code, end) == '.' && !isDigit(charAtOr(code, end + 1))) return true;
      i = end + 1;
    }
    return false;
  }

  static function charAtOr(text:String, index:Int):String
  {
    return (index < 0 || index >= text.length) ? ' ' : text.charAt(index);
  }

  static function isDigit(char:String):Bool
  {
    return char >= '0' && char <= '9';
  }

  static function isIdentifierChar(char:String):Bool
  {
    return (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') || char == '_' || isDigit(char);
  }

  /**
   * The `//` comment block directly above `marker`, joined into one line, or
   * `null` when there is none. Mirrors what the API-reference generator
   * harvests, so what the docs will show is what this asserts exists.
   */
  static function commentAbove(source:String, marker:String):String
  {
    final start:Int = source.indexOf(marker);
    if (start < 0) return null;

    final lines:Array<String> = source.substr(0, start).split('\n');
    final collected:Array<String> = [];
    var i:Int = lines.length - 2; // the line above the marker
    while (i >= 0)
    {
      final trimmed:String = lines[i].trim();
      if (trimmed.indexOf('//') == 0)
      {
        collected.unshift(trimmed.substr(2).trim());
      }
      else if (trimmed.length == 0)
      {
        if (collected.length > 0) break;
      }
      else
      {
        break;
      }
      i--;
    }
    return collected.length > 0 ? collected.join(' ') : null;
  }

  /** `[type, name]` for every `uniform` declaration, in source order. */
  static function uniformsOf(glsl:String):Array<Array<String>>
  {
    final out:Array<Array<String>> = [];
    final pattern:EReg = ~/[ \t]*uniform[ \t]+(float|bool|int|vec2|vec3|vec4)[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*;/g;
    var code:String = stripComments(glsl);
    while (pattern.match(code))
    {
      out.push([pattern.matched(1), pattern.matched(2)]);
      code = pattern.matchedRight();
    }
    return out;
  }

  static function componentsOf(type:String):Int
  {
    return switch (type)
    {
      case 'vec2': 2;
      case 'vec3': 3;
      case 'vec4': 4;
      default: 1;
    }
  }

  /** The `{...}` block that follows `marker`, matched by brace depth. */
  static function blockAfter(source:String, marker:String):String
  {
    final start:Int = source.indexOf(marker);
    if (start < 0) return null;

    var i:Int = source.indexOf('{', start);
    if (i < 0) return null;

    final begin:Int = i;
    var depth:Int = 0;
    while (i < source.length)
    {
      final char:String = source.charAt(i);
      if (char == '{') depth++;
      else if (char == '}')
      {
        depth--;
        if (depth == 0) return source.substr(begin, i - begin + 1);
      }
      i++;
    }
    return null;
  }
}
