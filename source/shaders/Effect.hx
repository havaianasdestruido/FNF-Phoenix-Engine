package shaders;

import flixel.system.FlxAssets.FlxShader;

class Effect
{
  /**
   * Executes the `setValue` operation.
   * @param shader Input value for `shader`.
   * @param variable Input value for `variable`.
   * @param value Input value for `value`.
   * @return Result produced by `setValue`, when applicable.
   */
  public function setValue(shader:FlxShader, variable:String, value:Float)
  {
    Reflect.setProperty(Reflect.getProperty(shader, variable), 'value', [value]);
  }
}
