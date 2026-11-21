package objects;

import psychlua.ModchartSprite;

/**
 * A stage-JSON prop. Same Lua/Python surface as `makeLuaSprite` (`playAnim`,
 * `animOffsets`) plus the editor fields (`danceEvery`, `firstAnimation`) so a
 * script can tween a named object the Stage Editor saved.
 */
class StagePropSprite extends ModchartSprite
{
	/** Stage-JSON `name`; also the Lua/Python tag. */
	public var objectName:String = '';
	/** `sprite`, `animatedSprite` or `square`. */
	public var objectType:String = 'sprite';
	/** Animation replayed on the beat when `danceEvery` > 0. */
	public var firstAnimation:String = null;
	/** Beats between idle replays. 0 leaves looping anims alone. */
	public var danceEvery:Float = 0;
	/** Psych quality/story filter mask. */
	public var filters:Int = 3;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
	}

	/** Replay the idle/first animation. Called from `JsonStage.beatHit`. */
	public function dance(?force:Bool = true):Void
	{
		if (firstAnimation != null && firstAnimation.length > 0 && animation.exists(firstAnimation))
			playAnim(firstAnimation, force);
	}
}
