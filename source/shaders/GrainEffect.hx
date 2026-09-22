package shaders;

import play.PlayState;

class GrainEffect extends Effect
{
  public var shader:Grain;

  /**
   * Executes the `new` operation.
   * @param grainsize Input value for `grainsize`.
   * @param lumamount Input value for `lumamount`.
   * @param lockAlpha Input value for `lockAlpha`.
   */
  public function new(grainsize, lumamount, lockAlpha)
  {
    shader = new Grain();
    shader.lumamount.value = [lumamount];
    shader.grainsize.value = [grainsize];
    shader.lockAlpha.value = [lockAlpha];
    shader.uTime.value = [FlxG.random.float(0, 8)];
    PlayState.instance.shaderUpdates.push(update);
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   * @return Result produced by `update`, when applicable.
   */
  public function update(elapsed)
  {
    shader.uTime.value[0] += elapsed;
  }
}
