import backend.MenuMusicLogic;

/**
 * Renderer-free contract for the menu music volume preference and its fades.
 * Run with: bash tests/haxe/run-menu-music.sh
 */
class MenuMusicSpec
{
  static var failures:Int = 0;

  static function main():Void
  {
    volumePreference();
    rampCeilings();
    fadeDecision();
    fadeLength();
    manualRamp();

    if (failures > 0) throw '$failures menu music check(s) failed';
    trace('MenuMusicSpec passed');
  }

  /* ------------------------------------------------------------------ *
   * The preference is a 0..1 volume; a broken save falls back to full.
   * ------------------------------------------------------------------ */
  static function volumePreference():Void
  {
    final L = MenuMusicLogic;

    close(L.volume(1), 1, 'full volume stays full');
    close(L.volume(0.35), 0.35, 'a normal value is kept as-is');
    close(L.volume(0), 0, '0 means the player muted the menus');
    close(L.volume(-1), L.DEFAULT_VOLUME, 'a negative save is treated as missing');
    close(L.volume(null), L.DEFAULT_VOLUME, 'a missing value uses the default');
    close(L.volume(Math.NaN), L.DEFAULT_VOLUME, 'NaN cannot mute the menus');
    close(L.volume(4), 1, 'values above 1 clamp');
    close(L.volume(0.0001), 0.0001, 'quiet values survive');
  }

  /* ------------------------------------------------------------------ *
   * Menu states keep their own ramp ceilings, but never above the pref.
   * ------------------------------------------------------------------ */
  static function rampCeilings():Void
  {
    final L = MenuMusicLogic;

    close(L.rampCap(0.8, 1), 0.8, 'default volume keeps the old 0.8 main menu ceiling');
    close(L.rampCap(0.7, 1), 0.7, 'default volume keeps the old 0.7 Freeplay ceiling');
    close(L.rampCap(0.8, 0.5), 0.5, 'a quieter preference wins over the ceiling');
    close(L.rampCap(0.7, 2), 0.7, 'an over-range preference cannot raise the ceiling');
    close(L.rampCap(0.7, 0), 0, 'muted menus stay muted');
    close(L.rampCap(Math.NaN, 0.4), 0.4, 'a NaN ceiling falls back to the preference');
    close(L.rampCap(-1, 0.4), 0, 'a negative ceiling clamps to silence');
  }

  /* ------------------------------------------------------------------ *
   * Fades are skipped when disabled, silent, or the move is inaudible.
   * ------------------------------------------------------------------ */
  static function fadeDecision():Void
  {
    final L = MenuMusicLogic;

    check(L.shouldFade(true, 1, 0), 'enabled fade from full to silence');
    check(L.shouldFade(true, 0, 1), 'enabled fade from silence to full');
    check(!L.shouldFade(false, 1, 0), 'the option off always cuts');
    check(!L.shouldFade(true, 0.5, 0.5), 'no move, no fade');
    check(!L.shouldFade(true, 0.5, 0.5005), 'a sub-epsilon move does not fade');
    check(!L.shouldFade(true, Math.NaN, 0), 'a NaN volume does not fade');
    check(!L.shouldFade(true, 2, 1), 'volumes outside 0..1 clamp before the comparison');

    close(L.fadeSeconds(1, 0, false), 0, 'fade length is 0 when the option is off');
    close(L.fadeSeconds(0.5, 0.5), 0, 'fade length is 0 without a move');
    close(L.fadeSeconds(1, 0), L.FULL_FADE_SECONDS, 'a full fade takes the full length');
    close(L.fadeSeconds(1, 0.5), L.FULL_FADE_SECONDS * 0.5, 'half the distance takes half the time');
    close(L.fadeSeconds(0.01, 0), 0, 'a fade below the minimum is not started');
  }

  /* ------------------------------------------------------------------ *
   * fadeSeconds only ever returns lengths it can actually render.
   * ------------------------------------------------------------------ */
  static function fadeLength():Void
  {
    final L = MenuMusicLogic;

    // Anything the helper may return is either "cut now" or a usable tween.
    final cases:Array<Float> = [-1, 0, 0.02, 0.1, 0.4, 0.75, 1, 2];
    for (from in cases)
    {
      for (to in cases)
      {
        final seconds:Float = L.fadeSeconds(from, to, true);
        check(seconds >= 0, 'a fade length is never negative ($from -> $to)');
        check(seconds == 0 || seconds >= L.MIN_FADE_SECONDS, 'a started fade is at least the minimum ($from -> $to)');
        check(seconds <= L.FULL_FADE_SECONDS, 'a fade never exceeds the full length ($from -> $to)');
      }
    }
  }

  /* ------------------------------------------------------------------ *
   * Manual per-frame ramps: linear, monotonic, no overshoot.
   * ------------------------------------------------------------------ */
  static function manualRamp():Void
  {
    final L = MenuMusicLogic;

    close(L.step(0, 1, 0.1, 0.5), 0.05, 'one frame at half a volume per second');
    close(L.step(0.99, 1, 0.1, 0.5), 1, 'the ramp stops exactly on target');
    close(L.step(1, 0.2, 0.1, 0.5), 0.95, 'a ramp can go down as well');
    close(L.step(0.2, 0.2, 1, 0.5), 0.2, 'a ramp at target does nothing');
    close(L.step(0.4, 1, 0, 0.5), 0.4, 'a frozen frame changes nothing');
    close(L.step(0.4, 1, 1, 0), 0.4, 'a zero speed changes nothing');
    close(L.step(0.4, 1, -1, 0.5), 0.4, 'negative elapsed changes nothing');
    close(L.step(0.4, 1, 1, -0.5), 0.4, 'a negative speed changes nothing');
    check(Math.isNaN(L.step(Math.NaN, 1, 1, 0.5)), 'a NaN volume stays NaN instead of jumping');
    close(L.step(0.4, Math.NaN, 1, 0.5), 0.4, 'a NaN target leaves the volume alone');
    close(L.step(0.4, 1, 0.0001, 0.5), 0.40005, 'a tiny frame only moves a tiny step');

    // A ramp fed frame after frame reaches the target and stays there.
    var volume:Float = 0;
    for (i in 0...240) volume = L.step(volume, 0.8, 1 / 60, 0.5);
    close(volume, 0.8, 'the ramp converges on its target');
  }

  static function close(actual:Float, expected:Float, message:String):Void
  {
    if (actual == expected) return;
    // Tolerate float noise from multiplication, not real mistakes.
    if (Math.abs(actual - expected) < 1e-6) return;
    failures++;
    trace('FAIL: $message (expected $expected, got $actual)');
  }

  static function check(condition:Bool, message:String):Void
  {
    if (condition) return;
    failures++;
    trace('FAIL: $message');
  }
}
