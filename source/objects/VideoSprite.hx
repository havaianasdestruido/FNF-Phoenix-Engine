package objects;

import backend.ClientPrefs;
import backend.Controls;
import flixel.addons.display.FlxPieDial;
#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

class VideoSprite extends FlxSpriteGroup
{
  #if VIDEOS_ALLOWED
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

  /**
   * Executes the `new` operation.
   * @param videoName Input value for `videoName`.
   * @param isWaiting Input value for `isWaiting`.
   * @param canSkip Input value for `canSkip`.
   * @param shouldLoop Input value for `shouldLoop`.
   * @param autoPause Input value for `autoPause`.
   */
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

  /**
   * Executes the `destroy` operation.
   * @return Result produced by `destroy`, when applicable.
   */
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

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   * @return Result produced by `update`, when applicable.
   */
  override function update(elapsed:Float)
  {
    if (canSkip)
    {
      if (Controls.instance != null && Controls.instance.ACCEPT_P)
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

  /**
   * Executes the `set_canSkip` operation.
   * @param newValue Input value for `newValue`.
   * @return Result produced by `set_canSkip`, when applicable.
   */
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

  /**
   * Executes the `updateSkipAlpha` operation.
   * @return Result produced by `updateSkipAlpha`, when applicable.
   */
  function updateSkipAlpha()
  {
    if (skipSprite == null) return;

    skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
    skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
  }

  /**
   * Executes the `play` operation.
   * @return Result produced by `play`, when applicable.
   */
  public function play()
    videoSprite?.play();

  /**
   * Executes the `resume` operation.
   * @return Result produced by `resume`, when applicable.
   */
  public function resume()
    videoSprite?.resume();

  /**
   * Executes the `pause` operation.
   * @return Result produced by `pause`, when applicable.
   */
  public function pause()
    videoSprite?.pause();
  #end
}