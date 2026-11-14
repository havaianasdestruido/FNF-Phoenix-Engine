package shaders;

import flixel.util.FlxColor;

/**
 * Flat single-colour character (see `shaders.SilhouetteShader`).
 *
 * Ported from Mario Madness (`SilhouetteShader`); credits and the list of local
 * changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var silhouette = new shaders.SilhouetteEffect(FlxColor.BLACK);
 * boyfriend.shader = silhouette.shader;   // per sprite
 * game.addShaderToCamera('game', silhouette); // or over a whole camera
 * silhouette.amount = 0.5;                // half way back to the real sprite
 * ```
 *
 * From Lua/Python/HScript: `addSilhouetteEffect('boyfriend', 0x000000)` — the
 * colour also accepts a name or hex string (`'red'`, `'0xFF0000'`, `'#FF0000'`).
 */
class SilhouetteEffect extends Effect
{
  public var shader:SilhouetteShader = new SilhouetteShader();

  /** The flat colour the sprite is reduced to. */
  public var color(default, set):FlxColor = FlxColor.BLACK;

  /** How much of the original picture is replaced: 0.0 untouched, 1.0 a pure silhouette. */
  public var amount(default, set):Float = 1.0;

  /**
   * @param color The flat colour the sprite is reduced to.
   * @param amount How much of the original picture is replaced (0.0 to 1.0).
   */
  public function new(color:FlxColor = FlxColor.BLACK, amount:Float = 1.0)
  {
    this.color = color;
    this.amount = amount;
  }

  function set_color(v:FlxColor):FlxColor
  {
    color = v;
    shader.uColor.value[0] = v.redFloat;
    shader.uColor.value[1] = v.greenFloat;
    shader.uColor.value[2] = v.blueFloat;
    return v;
  }

  function set_amount(v:Float):Float
  {
    amount = v;
    shader.uAmount.value[0] = Math.max(0.0, Math.min(1.0, v));
    return v;
  }
}
