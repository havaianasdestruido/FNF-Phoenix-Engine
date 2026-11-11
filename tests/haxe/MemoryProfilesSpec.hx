import backend.MemoryProfiles;
import backend.MemoryProfiles.MemoryProfile;
import backend.MemoryProfiles.StoredBaseline;

/**
 * Contract for the memory profiles behind Options -> Optimization.
 *
 * `backend.MemoryProfiles` is deliberately Flixel-free, so this runs in the
 * Haxe interpreter with no stubs: every assertion below is about the data that
 * ends up forced into `ClientPrefs` and about the cleanup policy that
 * `backend.LowMemory` follows.
 *
 * The companion script (`run-memory-profiles.sh`) also greps
 * `source/backend/ClientPrefs.hx` for every key used here, so a renamed
 * preference fails the run instead of silently disabling part of a profile.
 */
class MemoryProfilesSpec
{
  static function main():Void
  {
    testNormalize();
    testOff();
    testLow();
    testExtreme();
    testExtremeIsASupersetOfLow();
    testManagedKeys();
    testOverridesAreCopies();
    testBaselineRoundTrip();
    testBaselineRejectsJunk();
    testCoerce();
    testSummary();

    trace('MemoryProfilesSpec passed');
  }

  // -- Lookup ----------------------------------------------------------------

  static function testNormalize():Void
  {
    equal(MemoryProfiles.normalize(null), MemoryProfiles.OFF, 'null resolves to Off');
    equal(MemoryProfiles.normalize(''), MemoryProfiles.OFF, 'blank resolves to Off');
    equal(MemoryProfiles.normalize('   '), MemoryProfiles.OFF, 'whitespace resolves to Off');
    equal(MemoryProfiles.normalize('off'), MemoryProfiles.OFF, 'off is case-insensitive');
    equal(MemoryProfiles.normalize(' Off '), MemoryProfiles.OFF, 'surrounding spaces are ignored');
    equal(MemoryProfiles.normalize('none'), MemoryProfiles.OFF, 'none is an Off alias');
    equal(MemoryProfiles.normalize('low'), MemoryProfiles.LOW, 'low resolves');
    equal(MemoryProfiles.normalize('LOW MEMORY'), MemoryProfiles.LOW, 'CNE wording resolves to Low');
    equal(MemoryProfiles.normalize('lowmemory'), MemoryProfiles.LOW, 'camel-case-ish spelling resolves');
    equal(MemoryProfiles.normalize('light'), MemoryProfiles.LOW, 'light is a Low alias');
    equal(MemoryProfiles.normalize('extreme'), MemoryProfiles.EXTREME, 'extreme resolves');
    equal(MemoryProfiles.normalize('aggressive'), MemoryProfiles.EXTREME, 'aggressive is an Extreme alias');
    equal(MemoryProfiles.normalize('banana'), MemoryProfiles.OFF, 'unknown text falls back to Off');

    check(MemoryProfiles.isOff('nonsense'), 'an unknown profile counts as Off');
    check(!MemoryProfiles.isOff(MemoryProfiles.LOW), 'Low is not Off');

    // One immutable instance per profile: identity is a cheap cache check and
    // proves that normalizing does not rebuild (or leak) a profile per frame.
    check(MemoryProfiles.get('low') == MemoryProfiles.get(' LOW MEMORY '),
      'aliases share the cached profile instance');
  }

  static function testOff():Void
  {
    final profile:MemoryProfile = MemoryProfiles.get(MemoryProfiles.OFF);
    equal(profile.id, MemoryProfiles.OFF, 'Off keeps its id');
    equal(count(profile.overrides), 0, 'Off forces nothing');
    check(!profile.policy.trimOnSongEnd, 'Off does not trim after songs');
    check(!profile.policy.releaseOnPlayStateExit, 'Off does not release on song exit');
    check(!profile.policy.trimOnFocusLost, 'Off does not react to focus loss');
    close(profile.policy.idleTrimSeconds, 0, 'Off has no idle trim');
    check(profile.description.length > 0, 'Off has a description for the menu');
  }

  static function testLow():Void
  {
    final profile:MemoryProfile = MemoryProfiles.get(MemoryProfiles.LOW);
    equal(profile.title, 'Low', 'menu title');
    check(profile.description.indexOf('forced') != -1, 'the description warns that values are forced');

    equal(forced(profile, 'maxSplashLimit'), 4, 'Low caps the splash pool');
    check(Std.isOfType(forced(profile, 'maxSplashLimit'), Int), 'maxSplashLimit stays an Int');
    equal(forced(profile, 'movingMenuCheckerboard'), false, 'Low drops the moving menu backdrop');

    check(profile.policy.trimOnSongEnd, 'Low trims unused assets after songs');
    check(!profile.policy.releaseOnPlayStateExit, 'Low leaves the deep release to Extreme');
    check(profile.policy.trimOnFocusLost, 'Low trims when the window is backgrounded');
    close(profile.policy.idleTrimSeconds, 45, 'Low walks the cache every 45 s while idle');

    check(forced(profile, 'lowQuality') == null, 'Low does not touch stage detail');
    check(forced(profile, 'shaders') == null, 'Low does not touch shaders');
  }

  static function testExtreme():Void
  {
    final profile:MemoryProfile = MemoryProfiles.get(MemoryProfiles.EXTREME);
    equal(profile.title, 'Extreme', 'menu title');

    equal(forced(profile, 'lowQuality'), true, 'Extreme enables Low Quality stages');
    equal(forced(profile, 'noteSplashes'), false, 'Extreme disables note splashes');
    equal(forced(profile, 'oppNoteSplashes'), false, 'Extreme disables opponent splashes');
    equal(forced(profile, 'maxSplashLimit'), 0, 'Extreme allows no splash sprites');
    equal(forced(profile, 'shaders'), false, 'Extreme disables shaders');
    equal(forced(profile, 'globalAntialiasing'), false, 'Extreme disables anti-aliasing');
    equal(forced(profile, 'camZooms'), false, 'Extreme disables camera bop zooms');
    equal(forced(profile, 'movingMenuCheckerboard'), false, 'Extreme drops the moving menu backdrop');

    check(profile.policy.trimOnSongEnd, 'Extreme trims after songs');
    check(profile.policy.releaseOnPlayStateExit, 'Extreme releases everything once PlayState is gone');
    check(profile.policy.trimOnFocusLost, 'Extreme trims on focus loss');
    close(profile.policy.idleTrimSeconds, 20, 'Extreme walks the cache every 20 s while idle');

    // Gameplay must stay playable: these would change how a chart plays.
    check(forced(profile, 'charsAndBG') == null, 'Extreme keeps characters and backgrounds');
    check(forced(profile, 'downScroll') == null, 'Extreme does not touch scroll direction');
    check(forced(profile, 'noteSpeed') == null, 'Extreme does not touch scroll speed');
  }

  static function testExtremeIsASupersetOfLow():Void
  {
    final low:Map<String, Dynamic> = MemoryProfiles.overrides(MemoryProfiles.LOW);
    final extreme:Map<String, Dynamic> = MemoryProfiles.overrides(MemoryProfiles.EXTREME);

    for (field => value in low)
    {
      check(extreme.exists(field), 'Extreme keeps Low\'s "$field"');
      // Where both define a field, Extreme is at least as strict: turning a
      // switch off (or capping a number lower) may not be undone by upgrading.
      if (value is Bool) check(extreme.get(field) == value, 'Extreme agrees on boolean "$field"');
      if (value is Int) check(extreme.get(field) <= value, 'Extreme is at least as strict on "$field"');
    }

    check(MemoryProfiles.policy(MemoryProfiles.EXTREME).idleTrimSeconds
      < MemoryProfiles.policy(MemoryProfiles.LOW).idleTrimSeconds, 'Extreme cleans up more often');
  }

  static function testManagedKeys():Void
  {
    final keys:Array<String> = MemoryProfiles.managedKeys();
    check(keys.length > 0, 'some preferences are managed');
    check(keys.indexOf('memoryProfile') == -1, 'the profile option never manages itself');
    check(keys.indexOf('memoryProfileBaseline') == -1, 'the snapshot is not a managed preference');
    check(keys.indexOf('lowMemoryMode') == -1, 'the legacy mirror is derived, not forced');
    check(keys.indexOf('maxSplashLimit') != -1, 'the splash cap is listed');

    for (i in 1...keys.length)
      check(keys[i - 1] < keys[i], 'managedKeys() is sorted without duplicates');
  }

  static function testOverridesAreCopies():Void
  {
    final first:Map<String, Dynamic> = MemoryProfiles.overrides(MemoryProfiles.LOW);
    first.set('maxSplashLimit', 999);
    equal(forced(MemoryProfiles.get(MemoryProfiles.LOW), 'maxSplashLimit'), 4,
      'mutating the returned map cannot change the cached profile');
  }

  // -- Baseline --------------------------------------------------------------

  static function testBaselineRoundTrip():Void
  {
    final values:Map<String, Dynamic> = new Map<String, Dynamic>();
    values.set('maxSplashLimit', 16);
    values.set('movingMenuCheckerboard', true);
    values.set('profileNameNote', 'kept');

    final raw:String = MemoryProfiles.encodeBaseline('low', values);
    final stored:StoredBaseline = MemoryProfiles.decodeBaseline(raw);
    check(stored != null, 'a baseline round-trips');
    equal(stored.profile, MemoryProfiles.LOW, 'the profile id is normalized on the way in');
    equal(count(stored.values), 3, 'every primitive is kept');

    // The live preference decides the type; this is what makes JSON (which has
    // no Int/Float split) safe to write straight back into ClientPrefs.
    final storedLimit:Dynamic = stored.values.get('maxSplashLimit');
    final coerced:Dynamic = MemoryProfiles.coerce(9, storedLimit);
    check(Std.isOfType(coerced, Int), 'a JSON number coerces back to Int');
    equal(coerced, 16, 'the value survives the round trip');
    equal(MemoryProfiles.coerce(true, stored.values.get('movingMenuCheckerboard')), true, 'booleans survive');
    equal(MemoryProfiles.coerce('', stored.values.get('profileNameNote')), 'kept', 'strings survive');
  }

  static function testBaselineRejectsJunk():Void
  {
    check(MemoryProfiles.decodeBaseline(null) == null, 'null is not a baseline');
    check(MemoryProfiles.decodeBaseline('') == null, 'blank is not a baseline');
    check(MemoryProfiles.decodeBaseline('{') == null, 'truncated JSON is ignored');
    check(MemoryProfiles.decodeBaseline('[]') == null, 'JSON without values is ignored');
    check(MemoryProfiles.decodeBaseline('{"profile":"Low"}') == null, 'a baseline with no values is ignored');
    check(MemoryProfiles.decodeBaseline('{"profile":"Low","values":{}}') == null, 'an empty snapshot is ignored');

    final filtered:StoredBaseline =
      MemoryProfiles.decodeBaseline('{"profile":"Low","values":{"keep":true,"drop":{"nested":1},"nil":null}}');
    check(filtered != null, 'a mixed snapshot is still usable');
    equal(count(filtered.values), 1, 'only primitives are kept');
    equal(filtered.values.get('keep'), true, 'the primitive is the one that survived');

    final unknown:StoredBaseline = MemoryProfiles.decodeBaseline('{"values":{"a":1}}');
    check(unknown != null && unknown.profile == MemoryProfiles.OFF, 'a missing profile id resolves to Off');
  }

  static function testCoerce():Void
  {
    equal(MemoryProfiles.coerce(1, 2.9), 2, 'Float -> Int truncates');
    equal(MemoryProfiles.coerce(1, '7'), 7, 'numeric strings restore numeric preferences');
    equal(MemoryProfiles.coerce(1, 'eight'), 1, 'unparseable text keeps the current value');
    equal(MemoryProfiles.coerce(1.5, 2), 2.0, 'Int -> Float widens');
    equal(MemoryProfiles.coerce(true, 'false'), false, 'the string "false" is not truthy');
    equal(MemoryProfiles.coerce(true, 'true'), true, 'the string "true" is truthy');
    equal(MemoryProfiles.coerce(true, 0), false, '0 is false for a boolean preference');
    equal(MemoryProfiles.coerce('a', 12), '12', 'numbers stringify for text preferences');
    equal(MemoryProfiles.coerce('keep', null), 'keep', 'a null value never overwrites');
    equal(MemoryProfiles.coerce(5, null), 5, 'null keeps the current value for numbers too');
  }

  static function testSummary():Void
  {
    equal(MemoryProfiles.summary(MemoryProfiles.OFF), 'Off', 'Off needs no summary');
    check(MemoryProfiles.summary(MemoryProfiles.LOW).indexOf('Low (') == 0, 'Low summary starts with the name');
    check(MemoryProfiles.summary(MemoryProfiles.LOW).indexOf('trims after songs') != -1, 'Low reports its trim');
    check(MemoryProfiles.summary(MemoryProfiles.EXTREME).indexOf('releases after songs') != -1,
      'Extreme reports the deep release');
    check(MemoryProfiles.summary(MemoryProfiles.EXTREME).indexOf('idle trim 20s') != -1,
      'Extreme reports its idle interval');
    check(MemoryProfiles.describe('nonsense') == MemoryProfiles.describe(MemoryProfiles.OFF),
      'an unknown profile describes Off');
  }

  // -- Helpers ---------------------------------------------------------------

  static function count(values:Map<String, Dynamic>):Int
  {
    var total:Int = 0;
    for (field in values.keys())
      if (field != null) total++;
    return total;
  }

  static function forced(profile:MemoryProfile, field:String):Dynamic
    return profile.overrides.get(field);

  static function check(value:Bool, message:String):Void
  {
    if (!value) throw message;
  }

  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }

  static function close(actual:Float, expected:Float, message:String):Void
  {
    if (Math.abs(actual - expected) > 0.0001) throw message + ': expected ' + expected + ', got ' + actual;
  }
}
