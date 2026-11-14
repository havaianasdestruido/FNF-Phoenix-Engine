import android.platform.AndroidHaptics;
import backend.ClientPrefs;
import backend.HapticFeedback;
import backend.PlatformSupport;
import play.PlayState;
import play.helpers.PlayStateHaptics;
import psychlua.FunkinLua;
import psychlua.PythonScript;
import psychlua.callbacks.HardwareCallbacks;
import psychlua.pystdlib.PyHardwareLib;

/**
 * Renderer-free contract for automatic note haptics and the shared Lua/Python
 * `vibrate()` callback. The Android bridge is a recording stub, so the runner
 * exercises both the Android and unsupported-target paths without JNI.
 */
class HapticFeedbackSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    modes();
    durations();
    gameplay();
    scriptCallbacks();
    trace('HapticFeedbackSpec: ok (' + PlatformSupport.describeCurrent() + ')');
  }

  static function modes():Void
  {
    equal(HapticFeedback.OFF, 'Off', 'off label');
    equal(HapticFeedback.MISSES, 'Misses', 'misses label');
    equal(HapticFeedback.HITS_AND_MISSES, 'Hits and Misses', 'hits and misses label');
    equal(HapticFeedback.CHOICES.join('|'), 'Off|Misses|Hits and Misses', 'menu choices');

    equal(HapticFeedback.durationFor(HapticFeedback.OFF, true), 0, 'off ignores hits');
    equal(HapticFeedback.durationFor(HapticFeedback.OFF, false), 0, 'off ignores misses');
    equal(HapticFeedback.durationFor(HapticFeedback.MISSES, true), 0, 'misses mode ignores hits');
    equal(HapticFeedback.durationFor(HapticFeedback.MISSES, false), HapticFeedback.MISS_DURATION_MS, 'misses mode pulses on misses');
    equal(HapticFeedback.durationFor(HapticFeedback.HITS_AND_MISSES, true), HapticFeedback.HIT_DURATION_MS, 'both mode pulses on hits');
    equal(HapticFeedback.durationFor(HapticFeedback.HITS_AND_MISSES, false), HapticFeedback.MISS_DURATION_MS, 'both mode pulses on misses');
    equal(HapticFeedback.durationFor('unknown', false), 0, 'unknown mode fails closed');
    equal(HapticFeedback.durationFor(null, false), 0, 'null mode fails closed');
  }

  static function durations():Void
  {
    equal(HapticFeedback.sanitizeDuration(null), HapticFeedback.DEFAULT_DURATION_MS, 'omitted duration');
    equal(HapticFeedback.sanitizeDuration(50), 50, 'integer duration');
    equal(HapticFeedback.sanitizeDuration(12.5), 13, 'float duration rounds');
    equal(HapticFeedback.sanitizeDuration('25'), 25, 'numeric string');
    equal(HapticFeedback.sanitizeDuration(HapticFeedback.MAX_DURATION_MS + 1), HapticFeedback.MAX_DURATION_MS, 'duration cap');
    equal(HapticFeedback.sanitizeDuration(0), 0, 'zero duration');
    equal(HapticFeedback.sanitizeDuration(-1), 0, 'negative duration');
    equal(HapticFeedback.sanitizeDuration('nope'), 0, 'invalid duration');
    equal(HapticFeedback.sanitizeDuration(Math.NaN), 0, 'NaN duration');
    equal(HapticFeedback.sanitizeDuration(Math.POSITIVE_INFINITY), 0, 'infinite duration');
  }

  static function gameplay():Void
  {
    final android:Bool = PlatformSupport.supports([PlatformSupport.ANDROID]);
    final state:PlayState = new PlayState();

    ClientPrefs.hapticFeedback = HapticFeedback.OFF;
    AndroidHaptics.reset();
    PlayStateHaptics.hit(state);
    PlayStateHaptics.miss(state);
    equal(AndroidHaptics.pulses.length, 0, 'off mode never pulses');

    ClientPrefs.hapticFeedback = HapticFeedback.MISSES;
    AndroidHaptics.reset();
    PlayStateHaptics.hit(state);
    PlayStateHaptics.miss(state);
    equal(AndroidHaptics.pulses.length, android ? 1 : 0, 'misses mode dispatch');
    if (android) equal(AndroidHaptics.pulses[0], HapticFeedback.MISS_DURATION_MS, 'miss pulse duration');

    ClientPrefs.hapticFeedback = HapticFeedback.HITS_AND_MISSES;
    AndroidHaptics.reset();
    PlayStateHaptics.hit(state);
    PlayStateHaptics.miss(state);
    equal(AndroidHaptics.pulses.length, android ? 2 : 0, 'both mode dispatch');
    if (android)
    {
      equal(AndroidHaptics.pulses[0], HapticFeedback.HIT_DURATION_MS, 'hit pulse duration');
      equal(AndroidHaptics.pulses[1], HapticFeedback.MISS_DURATION_MS, 'miss pulse duration');
    }

    // Covered/backgrounded/exporting gameplay must not start new automatic pulses.
    for (flag in [
      'paused',
      'endingSong',
      'isDead',
      'inCutscene',
      'transitioning',
      'ffmpegMode',
      'subState'
    ])
    {
      final blocked:PlayState = new PlayState();
      switch (flag)
      {
        case 'paused':
          blocked.paused = true;
        case 'endingSong':
          blocked.endingSong = true;
        case 'isDead':
          blocked.isDead = true;
        case 'inCutscene':
          blocked.inCutscene = true;
        case 'transitioning':
          blocked.transitioning = true;
        case 'ffmpegMode':
          blocked.ffmpegMode = true;
        case 'subState':
          blocked.subState = {};
      }
      AndroidHaptics.reset();
      PlayStateHaptics.hit(blocked);
      PlayStateHaptics.miss(blocked);
      equal(AndroidHaptics.pulses.length, 0, 'blocked while $flag');
    }
    AndroidHaptics.reset();
    PlayStateHaptics.hit(null);
    PlayStateHaptics.miss(null);
    equal(AndroidHaptics.pulses.length, 0, 'null state is safe');

    AndroidHaptics.reset();
    PlayStateHaptics.cancel();
    equal(AndroidHaptics.cancels, android ? 1 : 0, 'lifecycle cancel');
  }

  static function scriptCallbacks():Void
  {
    HardwareCallbacks.register(new FunkinLua());
    PyHardwareLib.register(new PythonScript());
    final luaVibrate:Dynamic = FunkinLua.registeredFunctions.get('vibrate');
    final pyVibrate:Dynamic = PythonScript.registeredFunctions.get('vibrate');
    equal(luaVibrate != null, true, 'Lua vibrate registered');
    equal(pyVibrate != null, true, 'Python vibrate registered');

    final android:Bool = PlatformSupport.supports([PlatformSupport.ANDROID]);
    AndroidHaptics.reset();
    final luaDefault:Bool = Reflect.callMethod(null, luaVibrate, []);
    final pyDefault:Bool = Reflect.callMethod(null, pyVibrate, []);
    equal(luaDefault, android, 'Lua default pulse result');
    equal(pyDefault, android, 'Python default pulse result');
    equal(AndroidHaptics.pulses.length, android ? 2 : 0, 'default pulse dispatch');
    if (android)
    {
      equal(AndroidHaptics.pulses[0], HapticFeedback.DEFAULT_DURATION_MS, 'Lua default duration');
      equal(AndroidHaptics.pulses[1], HapticFeedback.DEFAULT_DURATION_MS, 'Python default duration');
    }

    final cases:Array<{value:Dynamic, duration:Int}> = [
      {value: 25, duration: 25},
      {value: 12.5, duration: 13},
      {value: HapticFeedback.MAX_DURATION_MS + 100, duration: HapticFeedback.MAX_DURATION_MS},
      {value: null, duration: HapticFeedback.DEFAULT_DURATION_MS},
      {value: 0, duration: 0},
      {value: -5, duration: 0},
      {value: 'nope', duration: 0},
      {value: Math.NaN, duration: 0},
      {value: Math.POSITIVE_INFINITY, duration: 0}
    ];
    for (entry in cases)
    {
      AndroidHaptics.reset();
      final luaResult:Bool = Reflect.callMethod(null, luaVibrate, [entry.value]);
      final pyResult:Bool = Reflect.callMethod(null, pyVibrate, [entry.value]);
      equal(luaResult, pyResult, 'Lua/Python agree for ${entry.value}');
      final expected:Bool = android && entry.duration > 0;
      equal(luaResult, expected, 'pulse result for ${entry.value}');
      equal(AndroidHaptics.pulses.length, expected ? 2 : 0, 'pulse dispatch for ${entry.value}');
      if (expected)
      {
        equal(AndroidHaptics.pulses[0], entry.duration, 'Lua duration for ${entry.value}');
        equal(AndroidHaptics.pulses[1], entry.duration, 'Python duration for ${entry.value}');
      }
    }
  }
}
