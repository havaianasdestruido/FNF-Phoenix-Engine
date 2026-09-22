package psychlua;

import backend.ClientPrefs;

#if flxanimate
class ModchartAnimateSprite extends FlxAnimate
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	/**
	 * Executes the `new` operation.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 */
	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	/**
	 * Executes the `playAnim` operation.
	 * @param name Input value for `name`.
	 * @param forced Input value for `forced`.
	 * @param reverse Input value for `reverse`.
	 * @param startFrame Input value for `startFrame`.
	 * @return Result produced by `playAnim`, when applicable.
	 */
	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		anim.play(name, forced, reverse, startFrame);
		
		var daOffset = animOffsets.get(name);
		if (animOffsets.exists(name)) offset.set(daOffset[0], daOffset[1]);
	}

	/**
	 * Executes the `addOffset` operation.
	 * @param name Input value for `name`.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @return Result produced by `addOffset`, when applicable.
	 */
	public function addOffset(name:String, x:Float, y:Float)
	{
		animOffsets.set(name, [x, y]);
	}
}
#end