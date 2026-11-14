package play.helpers;

/**
 * Song-local, renderer-independent policy for sustained low frame rates.
 * Feed it one timestamp per rendered frame, not one per simulation update.
 * A completed one-second window, rounded to a whole FPS, must be below the
 * draw target three times in a row before another cosmetic is disabled.
 * Individual stalls and sub-frame timing jitter cannot immediately strip effects.
 */
class AdaptivePerformance
{
  public static inline final WINDOW_SECONDS:Float = 1.0;
  public static inline final LOW_WINDOWS:Int = 3;
  public static inline final GC_COOLDOWN_SECONDS:Float = 15.0;

  // Actions are a bit mask: a cosmetic change and a GC request can coincide.
  public static inline final NONE:Int = 0;
  public static inline final SPLASHES:Int = 1;
  public static inline final RATINGS:Int = 2;
  public static inline final CAMERA_ZOOMS:Int = 4;
  public static inline final COLLECT_GARBAGE:Int = 8;

  public var splashesDisabled(default, null):Bool = false;
  public var ratingsDisabled(default, null):Bool = false;
  public var cameraZoomsDisabled(default, null):Bool = false;

  var nextCosmetic:Int = 0;
  var windowStart:Float = -1;
  var lastFrame:Float = -1;
  var windowFrames:Int = 0;
  var lowWindows:Int = 0;
  var lastTarget:Float = 0;
  var lastCollection:Float = Math.NEGATIVE_INFINITY;

  public function new() {}

  /**
   * Forget only the measurements, never the song's already-disabled effects.
   * Use around pauses, focus changes, GC and other non-gameplay interruptions.
   */
  public function resetSamples():Void
  {
    windowStart = lastFrame = -1;
    windowFrames = lowWindows = 0;
    lastTarget = 0;
  }

  /**
   * @param now Monotonic-ish wall-clock seconds at a rendered frame.
   * @param active False while paused, unfocused, in a cutscene or outside a song.
   * @param targetFps Actual draw target, not the playback-speed-adjusted FPS counter.
   * @param splashesEnabled Whether the player's current splash preference is on.
   * @param ratingsEnabled Whether the player's current rating preference is on.
   * @param cameraZoomsEnabled Whether the player's camera-bop preference is on.
   * @return Bit mask of changes to apply; NONE for an incomplete/healthy window.
   */
  public function observeFrame(now:Float, active:Bool, targetFps:Float, splashesEnabled:Bool, ratingsEnabled:Bool,
    cameraZoomsEnabled:Bool):Int
  {
    if (!active || !Math.isFinite(now) || !Math.isFinite(targetFps) || targetFps <= 0)
    {
      resetSamples();
      return NONE;
    }

    // A backwards wall clock must not suppress GC until the old time catches up,
    // including when samples were reset just after the previous collection.
    if (now < lastCollection) lastCollection = Math.NEGATIVE_INFINITY;
    // A target change or a clock adjustment starts a fresh, fair measurement.
    if (targetFps != lastTarget || (lastFrame >= 0 && now < lastFrame)) resetSamples();
    lastTarget = targetFps;
    lastFrame = now;
    if (windowStart < 0)
    {
      windowStart = now;
      return NONE;
    }

    windowFrames++;
    final duration:Float = now - windowStart;
    if (duration < WINDOW_SECONDS) return NONE;

    final fps:Float = windowFrames / duration;
    windowStart = now;
    windowFrames = 0;
    // One whole-FPS resolution avoids treating 59.94Hz as a persistent drop
    // against a 60 FPS target, while still responding to smaller real drops.
    lowWindows = Math.round(fps) < targetFps ? lowWindows + 1 : 0;
    if (lowWindows < LOW_WINDOWS) return NONE;
    lowWindows = 0;

    // Skip settings already off, but remember each traversed step for this
    // song: a script changing a preference later cannot undo an override.
    var action:Int = NONE;
    while (nextCosmetic < 3 && action == NONE)
    {
      switch (nextCosmetic++)
      {
        case 0:
          splashesDisabled = true;
          if (splashesEnabled) action = SPLASHES;
        case 1:
          ratingsDisabled = true;
          if (ratingsEnabled) action = RATINGS;
        case 2:
          cameraZoomsDisabled = true;
          if (cameraZoomsEnabled) action = CAMERA_ZOOMS;
      }
    }

    // Continue requesting occasional GC even if all cosmetics were already
    // off; throttle it so the cleanup itself cannot become a GC storm.
    if (now - lastCollection >= GC_COOLDOWN_SECONDS)
    {
      lastCollection = now;
      action |= COLLECT_GARBAGE;
    }
    return action;
  }
}
