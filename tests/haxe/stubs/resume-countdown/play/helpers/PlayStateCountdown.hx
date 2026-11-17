package play.helpers;

import flixel.FlxSprite;
import play.PlayState;

/**
 * Mirrors the real `PlayStateCountdown` surface the resume helper uses. The
 * stage-image resolution itself is exercised by the engine build, not here.
 */
class PlayStateCountdown
{
  public static function introImageSet():Array<String>
  {
    return ['ready', 'set', 'go'];
  }

  public static function createCountdownSprite(state:PlayState, image:String, antialias:Bool):FlxSprite
  {
    state.createdSprites.push(image);
    return new FlxSprite();
  }
}
