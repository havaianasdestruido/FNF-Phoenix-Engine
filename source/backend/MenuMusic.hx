package backend;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

/**
 * Owns the menu theme's volume and its optional fade.
 *
 * `Paths.playMenuMusic` starts the track and hands it to `claim()`, which
 * remembers which `FlxSound` is the menu theme. Every later volume change in
 * the menu flow goes through `targetVolume()` / `ramp()` / `applyVolume()`, so
 * `ClientPrefs.menuMusicVolume` (Options -> Visuals and UI) survives the states
 * that used to hardcode `1` or a `0.8`/`0.7` ramp ceiling. Gameplay audio is
 * untouched: as soon as a song or a Freeplay preview replaces
 * `FlxG.sound.music`, `isMenuTrack()` turns false and nothing here applies.
 *
 * The volume keys and the sound tray keep working on top: they scale
 * `FlxG.sound.volume`, which multiplies every sound including this one.
 *
 * `states.LoadingState` calls `fadeOutForSong()` when a `PlayState` is about to
 * load. With `ClientPrefs.menuMusicFade` on, the theme fades out while the
 * loading screen covers the switch; otherwise it is cut exactly like before.
 */
class MenuMusic
{
  /** Volume per second used by the menu states' own ramps (main menu, Freeplay, Credits). */
  public static inline var RAMP_SPEED:Float = 0.5;

  /** The `FlxSound` this helper started as the menu theme, or null. */
  static var track:FlxSound = null;

  /** Running fade (fade out into a song); any direct volume change cancels it. */
  static var fade:FlxTween = null;

  /**
   * Volume the menu theme should play at.
   *
   * @param cap ceiling that a state wants on top of the preference, e.g. the
   *            `0.7` Freeplay and Credits stop at.
   */
  public static function targetVolume(?cap:Float = 1):Float
  {
    return MenuMusicLogic.rampCap(cap, ClientPrefs.menuMusicVolume);
  }

  /** Whether the music playing right now is still the theme `Paths.playMenuMusic` started. */
  public static function isMenuTrack():Bool
  {
    return track != null && FlxG.sound != null && FlxG.sound.music == track;
  }

  /**
   * Marks `sound` as the menu theme and sets the volume it starts at.
   *
   * @param volume start volume; a negative value (the default) uses
   *               `ClientPrefs.menuMusicVolume`. The title screen passes `0`
   *               and fades the theme in itself.
   */
  public static function claim(sound:FlxSound, ?volume:Float = -1):Void
  {
    cancelFade();
    track = sound;
    if (sound == null) return;

    sound.volume = (volume < 0) ? targetVolume() : MenuMusicLogic.volume(volume);
  }

  /**
   * Applies the preference to the theme that is playing right now.
   * Used by the Options row so the slider previews the new volume live
   * instead of restarting the track.
   */
  public static function applyVolume():Void
  {
    if (!isMenuTrack()) return;

    cancelFade();
    FlxG.sound.music.volume = targetVolume();
  }

  /**
   * Raises the menu theme toward `targetVolume(cap)` at `RAMP_SPEED` for the
   * states that fade it in from their own `update()`.
   *
   * Only ever turns the volume up: these states used to guard with
   * `volume < ceiling` themselves, and a theme that is already louder than the
   * preference (a manual tweak, the title reveal) must not be dragged down.
   * Skipped while a fade owns the volume and while the theme is paused, so a
   * muted or paused track is never turned back up here.
   */
  public static function ramp(elapsed:Float, ?cap:Float = 1, ?speed:Float = RAMP_SPEED):Void
  {
    if (fade != null || !isMenuTrack()) return;

    final music:FlxSound = FlxG.sound.music;
    if (!music.playing) return;

    final target:Float = targetVolume(cap);
    if (music.volume >= target) return;

    music.volume = MenuMusicLogic.step(music.volume, target, elapsed, speed);
  }

  /**
   * Fades the menu theme out because a song is taking over.
   *
   * Called by `states.LoadingState` right before a `PlayState` loads, which is
   * the only window where the theme can still be heard: `PlayState.create()`
   * stops whatever is left of it. Only the menu theme is touched -- a song,
   * preview or mod track playing on the music channel is left alone.
   *
   * With `ClientPrefs.menuMusicFade` off (or with nothing audible left to
   * fade) this does nothing at all, so the theme keeps playing through the
   * loading screen and is cut when the song starts, exactly like before the
   * option existed.
   */
  public static function fadeOutForSong():Void
  {
    if (!isMenuTrack()) return;

    final music:FlxSound = FlxG.sound.music;
    final seconds:Float = MenuMusicLogic.fadeSeconds(music.volume, MenuMusicLogic.MIN_VOLUME, ClientPrefs.menuMusicFade);
    if (seconds <= 0) return;

    cancelFade();
    fade = FlxTween.tween(music, {volume: MenuMusicLogic.MIN_VOLUME}, seconds, {
      ease: FlxEase.quadOut,
      onComplete: function(_) {
        fade = null;
        music.stop();
        if (track == music) track = null;
      }
    });
  }

  /**
   * Drops the tracked theme and any running fade without touching the audio.
   * `PlayState` calls this once it takes the music channel over.
   */
  public static function forget():Void
  {
    cancelFade();
    track = null;
  }

  static function cancelFade():Void
  {
    if (fade == null) return;

    fade.cancel();
    fade = null;
  }
}
