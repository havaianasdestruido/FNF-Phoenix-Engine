package shaders;

/**
 * Pixelate by block size (see `shaders.MosaicShader`).
 *
 * Ported from Mario Madness, where the shader is `openfl/MosaicShader.hx` and its
 * strength-setting wrapper is `SMWPixelBlurShader`; credits and the list of local
 * changes are on the shader class. The wrapper's `setStrength()` is kept here, so
 * one class covers both upstream names.
 *
 * Usage:
 * ```haxe
 * var mosaic = new shaders.MosaicEffect(8, 8);
 * game.addShaderToCamera('game', mosaic);
 * mosaic.setStrength(16, 4);   // wide blocks, the SMW pixel-blur look
 * mosaic.blockSizeX = 1.0;     // back to a sharp picture
 * ```
 *
 * From Lua/Python/HScript: `addMosaicEffect('game', 8)` or
 * `addSMWPixelBlurEffect('game', 16, 4)`.
 */
class MosaicEffect extends Effect
{
  /** Below this the effect is invisible; upstream's 0 turned the screen black. */
  public static inline var MIN_BLOCK_SIZE:Float = 1.0;

  public var shader:MosaicShader = new MosaicShader();

  /** Block width in render-target pixels (1.0 = no pixelation). */
  public var blockSizeX(default, set):Float = 1.0;

  /** Block height in render-target pixels (1.0 = no pixelation). */
  public var blockSizeY(default, set):Float = 1.0;

  /**
   * @param blockSizeX Block width in render-target pixels.
   * @param blockSizeY Block height, or `blockSizeX` again when omitted.
   */
  public function new(blockSizeX:Float = 1.0, ?blockSizeY:Null<Float>)
  {
    this.blockSizeX = blockSizeX;
    this.blockSizeY = blockSizeY != null ? blockSizeY : blockSizeX;
  }

  /**
   * Sets both axes at once. Kept under the name Mario Madness'
   * `SMWPixelBlurShader` used, so a port of that code reads the same.
   *
   * @param strengthX Block width in render-target pixels.
   * @param strengthY Block height, or `strengthX` again when omitted.
   */
  public function setStrength(strengthX:Float, ?strengthY:Null<Float>):Void
  {
    blockSizeX = strengthX;
    blockSizeY = strengthY != null ? strengthY : strengthX;
  }

  function set_blockSizeX(v:Float):Float
  {
    blockSizeX = v;
    shader.uBlocksize.value[0] = clampSize(v);
    return v;
  }

  function set_blockSizeY(v:Float):Float
  {
    blockSizeY = v;
    shader.uBlocksize.value[1] = clampSize(v);
    return v;
  }

  /** NaN and anything below one pixel would divide by zero or hide the picture. */
  static function clampSize(v:Float):Float
  {
    if (Math.isNaN(v)) return MIN_BLOCK_SIZE;
    return Math.max(MIN_BLOCK_SIZE, v);
  }
}
