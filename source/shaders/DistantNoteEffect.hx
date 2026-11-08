package shaders;

/**
 * Guitar-Hero-style perspective for the strumline: notes are skewed as if the
 * highway recedes into the distance. Ported from FNF-Doido-Engine's
 * `DistantNoteShader`.
 *
 * Usage:
 * ```haxe
 * var guitar = new shaders.DistantNoteEffect(ClientPrefs.downScroll);
 * game.addShaderToCamera('hud', guitar);
 * ```
 *
 * NOTE: force middlescroll while this is enabled — the perspective converges
 * at the center of the texture, so off-center note lanes look wrong.
 */
class DistantNoteEffect extends Effect
{
  public var shader:DistantNoteShader = new DistantNoteShader();

  /** Scroll direction the highway recedes in; keep it matched to the player's setting. */
  public var downscroll(default, set):Bool = false;

  /** Y the highway converges at (0.42 matches the original Doido shader). */
  public var pivot(default, set):Float = 0.42;

  /** How quickly the perspective opens up (0.8 matches the original Doido shader). */
  public var spread(default, set):Float = 0.8;

  /**
   * @param downscroll Scroll direction the highway recedes in.
   * @param pivot Y the highway converges at (0.42 matches the original Doido shader).
   * @param spread How quickly the perspective opens up (0.8 matches the original Doido shader).
   */
  public function new(downscroll:Bool = false, pivot:Float = 0.42, spread:Float = 0.8)
  {
    this.downscroll = downscroll;
    this.pivot = pivot;
    this.spread = spread;
  }

  function set_downscroll(v:Bool):Bool
  {
    downscroll = v;
    shader.uDownscroll.value = [v];
    return v;
  }

  function set_pivot(v:Float):Float
  {
    pivot = v;
    shader.uPivot.value = [v];
    return v;
  }

  function set_spread(v:Float):Float
  {
    spread = v;
    shader.uSpread.value = [v];
    return v;
  }
}
