package shaders;

import play.PlayState;

class BlockedGlitchEffect
{
  public var shader(default, null):BlockedGlitchShader = new BlockedGlitchShader();

  public var time(default, set):Float = 0;
  public var resolution(default, set):Float = 0;
  public var colorMultiplier(default, set):Float = 0;
  public var hasColorTransform(default, set):Bool = false;

  /**
   * Executes the `new` operation.
   * @param res Input value for `res`.
   * @param time Input value for `time`.
   * @param colorMultiplier Input value for `colorMultiplier`.
   * @param colorTransform Input value for `colorTransform`.
   */
  public function new(res:Float, time:Float, colorMultiplier:Float, colorTransform:Bool):Void
  {
    set_time(time);
    set_resolution(res);
    set_colorMultiplier(colorMultiplier);
    set_hasColorTransform(colorTransform);
    PlayState.instance.shaderUpdates.push(update);
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   */
  public function update(elapsed:Float):Void
  {
    shader.time.value[0] += elapsed;
  }

  /**
   * Executes the `set_resolution` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_resolution`, when applicable.
   */
  public function set_resolution(v:Float):Float
  {
    resolution = v;
    shader.screenSize.value = [resolution];
    return this.resolution;
  }

  /**
   * Executes the `set_hasColorTransform` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_hasColorTransform`, when applicable.
   */
  function set_hasColorTransform(value:Bool):Bool
  {
    this.hasColorTransform = value;
    shader.hasColorTransform.value = [hasColorTransform];
    return hasColorTransform;
  }

  /**
   * Executes the `set_colorMultiplier` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_colorMultiplier`, when applicable.
   */
  function set_colorMultiplier(value:Float):Float
  {
    this.colorMultiplier = value;
    shader.colorMultiplier.value = [value];
    return this.colorMultiplier;
  }

  /**
   * Executes the `set_time` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_time`, when applicable.
   */
  function set_time(value:Float):Float
  {
    this.time = value;
    shader.time.value = [value];
    return this.time;
  }
}
