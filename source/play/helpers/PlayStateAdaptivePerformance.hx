package play.helpers;

import backend.ClientPrefs;
import backend.Paths;
import backend.ScreenLayout;
import backend.VLog;
import debug.FrameProfiler;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.system.System;
import play.PlayState;

/** Connects the pure adaptive policy to one PlayState's draw and cosmetic pools. */
@:access(play.PlayState)
class PlayStateAdaptivePerformance
{
  public final policy:AdaptivePerformance = new AdaptivePerformance();

  var state:PlayState;
  var focused:Bool = true;
  var frameListener:Void->Void;
  var notice:FlxText;
  var noticeTimer:FlxTimer;
  var reportedGcOnly:Bool = false;

  public function new(state:PlayState)
  {
    this.state = state;
    // The song may start while the app is already in the background (for
    // example with auto-pause disabled), after the focus-lost event was sent
    // to the preceding state. Inherit Flixel's current focus state as well.
    focused = FlxG.game == null || !(@:privateAccess FlxG.game._lostFocus);
    frameListener = onFrame;
    // Unlike update(), this fires once per actual draw even with a fixed timestep.
    FlxG.signals.postDraw.add(frameListener);
  }

  /** Reset the sampling window when focus changes, even with auto-pause off. */
  public function setFocused(value:Bool):Void
  {
    focused = value;
    policy.resetSamples();
  }

  /** Discard time spent in a pause/substate without restoring song overrides. */
  public function resetSamples():Void
  {
    policy.resetSamples();
  }

  /** Keep the notice in the same screen-space location after a resize. */
  public function repositionNotice():Void
  {
    if (notice == null) return;
    notice.x = ScreenLayout.contentLeft(FlxG.width) + 12;
    notice.y = FlxG.height - 58;
  }

  /** Remove the draw listener and timer before this PlayState is destroyed. */
  public function destroy():Void
  {
    FlxG.signals.postDraw.remove(frameListener);
    if (noticeTimer != null) noticeTimer.cancel();
    state = null;
  }

  function onFrame():Void
  {
    sample(haxe.Timer.stamp());
  }

  // The explicit timestamp also lets the integration spec drive real policy
  // decisions deterministically without depending on a display or frame timer.
  function sample(now:Float):Void
  {
    if (state == null) return;
    final playing:Bool = ClientPrefs.adaptivePerformance && focused && FlxG.state == state
      && state.startedCountdown && !state.startingSong && !state.endingSong && !state.inCutscene
      && !state.paused && !state.isDead && !state.transitioning && state.finishTimer == null
      && state.subState == null && !state.ffmpegMode;
    final action:Int = policy.observeFrame(now, playing, FlxG.drawFramerate, ClientPrefs.noteSplashes,
      ClientPrefs.ratingPopups, ClientPrefs.camZooms);
    if (action == AdaptivePerformance.NONE) return;

    var change:String = null;
    if ((action & AdaptivePerformance.SPLASHES) != 0)
    {
      clearSplashes();
      change = 'Note splashes off';
    }
    else if ((action & AdaptivePerformance.RATINGS) != 0)
    {
      clearRatings();
      change = 'Rating popups off';
    }
    else if ((action & AdaptivePerformance.CAMERA_ZOOMS) != 0)
    {
      change = 'Camera bops off';
    }

    var collected:Bool = false;
    if ((action & AdaptivePerformance.COLLECT_GARBAGE) != 0)
    {
      collected = requestGarbageCollection();
      // Never count the cleanup's own pause as another slow gameplay window.
      policy.resetSamples();
    }

    if (change != null)
    {
      showNotice('Adaptive performance: ' + change + '\n'
        + (collected ? 'For this song; memory cleanup requested.' : 'For this song only.'));
      VLog.memoryEvent('adaptive performance: ' + change + (collected ? '; GC requested' : ''));
    }
    else if (collected && !reportedGcOnly)
    {
      // If all three preferences were already off, still tell the player why
      // the first GC happened, without repeatedly interrupting a long song.
      reportedGcOnly = true;
      showNotice('Adaptive performance: low FPS\nMemory cleanup requested.');
      VLog.memoryEvent('adaptive performance: low FPS; GC requested');
    }
  }

  function clearSplashes():Void
  {
    if (state.grpNoteSplashes != null)
      for (splash in state.grpNoteSplashes.members)
        if (splash != null && splash.exists) splash.kill();
    if (state.grpHoldSplashes != null)
      for (splash in state.grpHoldSplashes.members)
        if (splash != null && splash.exists) splash.kill();
  }

  function clearRatings():Void
  {
    // Ratings and combo digits share a pool. Leave the independently enabled
    // combo numbers alone, including any already visible on screen.
    if (state.popUpGroup != null)
      for (popup in state.popUpGroup.members)
        if (popup != null && popup.exists && popup.isRatingPopup)
        {
          FlxTween.cancelTweensOf(popup);
          popup.kill();
        }
    if (state.timingGroup != null)
      for (label in state.timingGroup.members)
        if (label != null && label.exists) label.kill();
    if (state.judgeTxt != null)
    {
      FlxTween.cancelTweensOf(state.judgeTxt);
      FlxTween.cancelTweensOf(state.judgeTxt.scale);
      state.judgeTxt.visible = false;
    }
  }

  function showNotice(message:String):Void
  {
    if (notice == null)
    {
      notice = new FlxText(0, 0, 560, '', 16);
      notice.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
      notice.borderSize = 1.25;
      notice.scrollFactor.set();
      notice.cameras = [state.camOther]; // still visible with Hide HUD enabled
      state.add(notice);
      repositionNotice();
    }
    notice.text = message;
    notice.visible = true;
    if (noticeTimer == null) noticeTimer = new FlxTimer();
    else noticeTimer.cancel();
    noticeTimer.start(4.5, hideNotice);
  }

  function hideNotice(_:FlxTimer):Void
  {
    if (notice != null) notice.visible = false;
  }

  /** Request an explicit collection without changing the automatic-GC setting. */
  function requestGarbageCollection():Bool
  {
    // OpenFL exposes no explicit GC on browser builds. Flash/AIR may only
    // honour the request in debug players, so describe this as a request.
    #if (sys || flash)
    var requested:Bool = true;
    FrameProfiler.beginGC(true);
    try
    {
      System.gc();
    }
    catch (e:Dynamic)
    {
      requested = false;
      VLog.memoryEvent('adaptive performance: GC request failed: ' + Std.string(e));
    }
    FrameProfiler.endGC();
    return requested;
    #else
    return false;
    #end
  }
}
