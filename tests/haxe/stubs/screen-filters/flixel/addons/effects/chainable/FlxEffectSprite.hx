package flixel.addons.effects.chainable;

import flixel.FlxSprite;

/**
 * Stand-in for the addon's wrapper. The real class copies its target's pixels
 * through the chain every frame; the stub keeps the same public contract and
 * lets the spec drive `update()` by hand.
 */
class FlxEffectSprite extends FlxSprite
{
  public var effectsEnabled:Bool = true;
  public var target:FlxSprite;
  public var updateTargetAnimation:Bool = true;
  public var effects:Array<IFlxEffect>;
  public var updates:Int = 0;

  public function new(Target:FlxSprite, ?Effects:Array<IFlxEffect>)
  {
    super(Target.x, Target.y);
    target = Target;
    effects = (Effects != null) ? Effects : [];
  }

  override public function update(elapsed:Float):Void
  {
    updates++;
    if (effectsEnabled)
      for (effect in effects)
        if (effect.active) effect.update(elapsed);
  }
}
