package psychlua;

import StringTools;
import Type.ValueType;

/**
 * Validates the numeric fields passed to script-created FlxTweens.
 *
 * Modcharts sometimes produce NaN or infinity (for example, division by a
 * zero-valued wave term). FlxTween writes those values into the target object;
 * on the following frame VarTween rejects the now-invalid starting property
 * and the exception escapes the normal Lua callback error handling. Reject the
 * tween at the script boundary instead, before it can corrupt the target.
 */
class TweenValueValidation
{
  static final NUMBER_STRING:EReg = ~/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;

  /**
   * Makes a copy of a tween goal object with finite numeric values, but only
   * when every corresponding property on `target` is already a finite number.
   * Dotted paths such as `scale.x` are supported, matching FlxTween's API.
   *
   * `null` means the tween is unsafe and should not be created.
   */
  public static function sanitize(target:Dynamic, values:Dynamic):Dynamic
  {
    if (target == null || values == null) return null;

    final fields:Array<String> = Reflect.fields(values);
    final sanitized:Dynamic = {};
    for (field in fields)
    {
      final goal:Null<Float> = finiteNumber(Reflect.field(values, field));
      if (goal == null || !hasFiniteNumberAtPath(target, field)) return null;
      Reflect.setField(sanitized, field, goal);
    }
    return sanitized;
  }

  /** Parses a number or numeric string and rejects NaN, infinity, and other types. */
  public static function finiteNumber(value:Dynamic):Null<Float>
  {
    var number:Float;
    switch (Type.typeof(value))
    {
      case ValueType.TInt:
        number = value;
      case ValueType.TFloat:
        number = value;
      case ValueType.TClass(String):
        final text:String = StringTools.trim(cast value);
        if (!NUMBER_STRING.match(text)) return null;
        number = Std.parseFloat(text);
      default:
        return null;
    }

    return Math.isFinite(number) ? number : null;
  }

  static function hasFiniteNumberAtPath(target:Dynamic, path:String):Bool
  {
    var current:Dynamic = target;
    for (part in path.split('.'))
    {
      if (current == null) return false;
      current = Reflect.getProperty(current, part);
    }

    return switch (Type.typeof(current))
    {
      case ValueType.TInt: true;
      case ValueType.TFloat: Math.isFinite(current);
      default: false;
    };
  }
}
