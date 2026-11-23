import psychlua.TweenValueValidation;

/** Regression tests for the finite-number guard used by mod Lua tween APIs. */
class TweenValueValidationSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    check(TweenValueValidation.finiteNumber(4) == 4.0, 'integer tween values are accepted');
    check(TweenValueValidation.finiteNumber(1.25) == 1.25, 'float tween values are accepted');
    check(TweenValueValidation.finiteNumber('1.25') == 1.25, 'numeric string tween values are normalized');
    check(TweenValueValidation.finiteNumber(' -2.5e1 ') == -25.0, 'trimmed exponent strings are normalized');
    check(TweenValueValidation.finiteNumber('1.5px') == null, 'partially numeric strings are rejected');
    check(TweenValueValidation.finiteNumber('NaN') == null, 'NaN strings are rejected');
    check(TweenValueValidation.finiteNumber(Math.NaN) == null, 'NaN values are rejected');
    check(TweenValueValidation.finiteNumber(Math.POSITIVE_INFINITY) == null, 'positive infinity is rejected');
    check(TweenValueValidation.finiteNumber(Math.NEGATIVE_INFINITY) == null, 'negative infinity is rejected');

    final target:Dynamic = {x: 100.0, scale: {x: 0.7, y: 0.7}};
    final values:Dynamic = {x: '250.5'};
    Reflect.setField(values, 'scale.y', '1.25');
    final sanitized:Dynamic = TweenValueValidation.sanitize(target, values);
    check(sanitized != null, 'finite values for valid fields can be tweened');
    check(Reflect.field(sanitized, 'x') == 250.5, 'numeric strings become numbers');
    check(Reflect.field(sanitized, 'scale.y') == 1.25, 'dotted paths are preserved and normalized');

    check(TweenValueValidation.sanitize(target, {x: Math.NaN}) == null, 'a NaN goal rejects the entire tween');
    check(TweenValueValidation.sanitize(target, {x: Math.POSITIVE_INFINITY}) == null,
      'an infinite goal rejects the entire tween');
    check(TweenValueValidation.sanitize(target, {missing: 1}) == null, 'missing start properties are rejected');
    check(TweenValueValidation.sanitize({x: Math.NaN}, {x: 2}) == null, 'a corrupted start property is rejected');
    check(TweenValueValidation.sanitize({x: Math.POSITIVE_INFINITY}, {x: 2}) == null,
      'an infinite start property is rejected');

    Sys.println('TweenValueValidationSpec: PASS');
  }
}
