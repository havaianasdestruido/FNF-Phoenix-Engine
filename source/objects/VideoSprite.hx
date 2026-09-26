package objects;

import backend.ClientPrefs;
import backend.Controls;
import flixel.addons.display.FlxPieDial;
#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

#if (VIDEOS_ALLOWED && hxvlc)
class VideoSprite extends FlxSpriteGroup
{
  public var finishCallback:Void->Void = null;
  public var onSkip:Void->Void = null;

  final _timeToSkip:Float = 1;

  public var holdingTime:Float = 0;
  public var videoSprite:FlxVideoSprite;
  public var skipSprite:FlxPieDial;
  public var cover:FlxSprite;
  public var canSkip(default, set):Bool = false;

  private var videoName:String;

  public var waiting:Bool = false;

  public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false, autoPause:Bool = true)
  {
    super();

    this.videoName = videoName;
    scrollFactor.set();
    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

    waiting = isWaiting;
    if (!waiting)
    {
      cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
      cover.scale.set(FlxG.width + 100, FlxG.height + 100);
      cover.screenCenter();
      cover.scrollFactor.set();
      add(cover);
    }

    // initialize sprites
    videoSprite = new FlxVideoSprite();
    videoSprite.antialiasing = ClientPrefs.globalAntialiasing;
    videoSprite.autoPause = autoPause;
    add(videoSprite);
    if (canSkip) this.canSkip = true;

    // callbacks
    if (!shouldLoop) videoSprite.bitmap.onEndReached.add(destroy);

    videoSprite.bitmap.onFormatSetup.add(function() {
      /*
        #if hxvlc
        var wd:Int = videoSprite.bitmap.formatWidth;
        var hg:Int = videoSprite.bitmap.formatHeight;
        trace('Video Resolution: ${wd}x${hg}');
        videoSprite.scale.set(FlxG.width / wd, FlxG.height / hg);
        #end
       */
      videoSprite.setGraphicSize(FlxG.width);
      videoSprite.updateHitbox();
      videoSprite.screenCenter();
    });

    // start video and adjust resolution to screen size
    videoSprite.load(videoName, shouldLoop ? ['input-repeat=65545'] : null);
  }

  var alreadyDestroyed:Bool = false;

  override function destroy()
  {
    if (alreadyDestroyed) return;

    trace('Video destroyed');
    if (cover != null)
    {
      remove(cover);
      cover.destroy();
    }

    if (finishCallback != null) finishCallback();
    onSkip = null;

    if (FlxG.state != null)
    {
      if (FlxG.state.members.contains(this)) FlxG.state.remove(this);

      if (FlxG.state.subState != null && FlxG.state.subState.members.contains(this)) FlxG.state.subState.remove(this);
    }
    super.destroy();
    alreadyDestroyed = true;
  }

  override function update(elapsed:Float)
  {
    if (canSkip)
    {
      // Touch-only devices have no ACCEPT button bound during songs, so holding a touch skips too.
      var skipHeld:Bool = (Controls.instance != null && Controls.instance.ACCEPT_P);
      if (!skipHeld)
      {
        for (touch in FlxG.touches.list)
        {
          if (touch != null && touch.pressed)
          {
            skipHeld = true;
            break;
          }
        }
      }
      if (skipHeld)
      {
        holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
      }
      else if (holdingTime > 0)
      {
        holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
      }
      updateSkipAlpha();

      if (holdingTime >= _timeToSkip)
      {
        if (onSkip != null) onSkip();
        finishCallback = null;
        videoSprite.bitmap.onEndReached.dispatch();
        trace('Skipped video');
        return;
      }
    }
    super.update(elapsed);
  }

  function set_canSkip(newValue:Bool)
  {
    canSkip = newValue;
    if (canSkip)
    {
      if (skipSprite == null)
      {
        skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
        skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
        skipSprite.x = FlxG.width - (skipSprite.width + 80);
        skipSprite.y = FlxG.height - (skipSprite.height + 72);
        skipSprite.amount = 0;
        add(skipSprite);
      }
    }
    else if (skipSprite != null)
    {
      remove(skipSprite);
      skipSprite.destroy();
      skipSprite = null;
    }
    return canSkip;
  }

  function updateSkipAlpha()
  {
    if (skipSprite == null) return;

    skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
    skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
  }

  public function play()
    videoSprite?.play();

  public function resume()
    videoSprite?.resume();

  public function pause()
    videoSprite?.pause();
}
#else
/**
 * Graceful fallback used when the hxvlc video backend isn't available on
 * this platform (hxvlc is a desktop-only haxelib; mobile builds have
 * VIDEOS_ALLOWED set but no video decoder). The sprite keeps the same
 * public surface as the real one and immediately resolves its finish
 * callback, so cutscene/intro flows skip the video instead of hanging.
 */
class VideoSprite extends FlxSpriteGroup
{
  public var finishCallback:Void->Void = null;
  public var onSkip:Void->Void = null;

  public var holdingTime:Float = 0;
  public var videoSprite:NullVideoSpriteBackend = new NullVideoSpriteBackend();
  public var canSkip(default, set):Bool = false;

  private var videoName:String;

  public var waiting:Bool = false;

  var alreadyDestroyed:Bool = false;
  var resolved:Bool = false;

  public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false, autoPause:Bool = true)
  {
    super();

    this.videoName = videoName;
    waiting = isWaiting;
    if (canSkip) this.canSkip = true;

    trace('Video backend unavailable on this platform, skipping "$videoName"');
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    // Resolve the "video ended" flow one frame after construction so the
    // caller has had a chance to hook up finishCallback/onSkip first.
    if (!resolved)
    {
      resolved = true;
      destroy();
    }
  }

  override function destroy()
  {
    if (alreadyDestroyed) return;

    if (finishCallback != null) finishCallback();
    onSkip = null;

    if (FlxG.state != null)
    {
      if (FlxG.state.members.contains(this)) FlxG.state.remove(this);

      if (FlxG.state.subState != null && FlxG.state.subState.members.contains(this)) FlxG.state.subState.remove(this);
    }
    super.destroy();
    alreadyDestroyed = true;
  }

  function set_canSkip(newValue:Bool)
  {
    canSkip = newValue;
    return canSkip;
  }

  public function play() {}

  public function resume() {}

  public function pause() {}
}

/** Stand-in for `hxvlc.flixel.FlxVideoSprite` when no backend exists. */
class NullVideoSpriteBackend
{
  public function new() {}

  public function play() {}

  public function resume() {}

  public function pause() {}
}
#end
