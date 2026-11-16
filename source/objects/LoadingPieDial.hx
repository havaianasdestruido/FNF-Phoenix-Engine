package objects;

import backend.ClientPrefs;
import backend.LoadingDialLogic;
import flixel.FlxG;
import flixel.addons.display.FlxPieDial;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;

/**
 * Bottom-left circular progress indicator built from `FlxPieDial` for
 * loading screens (`states.LoadingState` and `mobile.CopyState`).
 *
 * Pairs a translucent dark backing ring with a colored clockwise `FlxPieDial`
 * so progress stays readable against both the bright `#CAFF4D` background and
 * custom per-song loading artwork.
 */
class LoadingPieDial extends FlxSpriteGroup
{
  /** Full-circle background ring behind the active arc. */
  public var trackDial(default, null):FlxPieDial;

  /** Clockwise progress arc driven by `setProgress()`. */
  public var progressDial(default, null):FlxPieDial;

  /** Last sanitized `0..1` amount applied to `progressDial`. */
  public var progress(default, null):Float = 0;

  /**
   * Creates a bottom-left `FlxPieDial` indicator.
   *
   * @param colorName optional preset name; defaults to `ClientPrefs.loadingPieDialColor`
   */
  public function new(?colorName:String)
  {
    super();

    final radius:Int = LoadingDialLogic.RADIUS;
    final innerRadius:Int = LoadingDialLogic.INNER_RADIUS;
    final frames:Int = LoadingDialLogic.FRAMES;
    final resolvedName:String = colorName != null ? colorName : ClientPrefs.loadingPieDialColor;
    final dialColor:FlxColor = LoadingDialLogic.colorValue(resolvedName);

    trackDial = new FlxPieDial(0, 0, radius, LoadingDialLogic.TRACK_COLOR, 1, FlxPieDialShape.CIRCLE, true, innerRadius);
    trackDial.amount = 1;
    trackDial.alpha = LoadingDialLogic.TRACK_ALPHA;
    trackDial.antialiasing = ClientPrefs.globalAntialiasing;
    trackDial.scrollFactor.set();
    add(trackDial);

    progressDial = new FlxPieDial(0, 0, radius, dialColor, frames, FlxPieDialShape.CIRCLE, true, innerRadius);
    progressDial.amount = 0;
    progressDial.antialiasing = ClientPrefs.globalAntialiasing;
    progressDial.scrollFactor.set();
    add(progressDial);

    scrollFactor.set();
    layout(FlxG.width, FlxG.height);
  }

  /**
   * Updates the displayed progress (`0..1`) without triggering `FlxPieDial`'s
   * frame-0 full-circle flash on tiny non-zero fractions.
   *
   * @param value normalized loading progress (`0..1`)
   */
  public function setProgress(value:Float):Void
  {
    progress = LoadingDialLogic.dialAmount(value, LoadingDialLogic.FRAMES);
    if (progressDial != null) progressDial.amount = progress;
  }

  /**
   * Anchors the dial in the bottom-left corner of the viewport.
   *
   * @param viewportWidth  optional width override (e.g. from `onResize`)
   * @param viewportHeight optional height override (e.g. from `onResize`)
   */
  public function layout(?viewportWidth:Int, ?viewportHeight:Int):Void
  {
    final w:Int = viewportWidth != null ? viewportWidth : FlxG.width;
    final h:Int = viewportHeight != null ? viewportHeight : FlxG.height;
    final diameter:Float = LoadingDialLogic.RADIUS * 2;
    final pos = LoadingDialLogic.position(w, h, diameter, diameter);
    setPosition(pos.x, pos.y);
  }
}
