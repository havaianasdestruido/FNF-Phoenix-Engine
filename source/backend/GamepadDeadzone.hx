package backend;

/**
 * Pure clamping helpers for `ClientPrefs.gamepadDeadzone` (`FlxG.gamepads.globalDeadZone`).
 *
 * `MIN` stays strictly above `0` because `FlxGamepad` compares `Math.abs(axis) > deadZone`;
 * a `0.0` deadzone causes resting analog-stick noise to fire digital stick inputs
 * every frame while still supporting low-drift Hall-effect sticks down to 2%.
 */
class GamepadDeadzone
{
  public static inline var DEFAULT:Float = 0.15;
  public static inline var MIN:Float = 0.02;
  public static inline var MAX:Float = 0.90;
  public static inline var STEP:Float = 0.01;

  public static function clamp(value:Float):Float
  {
    if (Math.isNaN(value) || !Math.isFinite(value))
      return DEFAULT;
    if (value < MIN)
      return MIN;
    if (value > MAX)
      return MAX;
    return Math.round(value * 100.0) / 100.0;
  }
}
