package objects;

import backend.Paths;
import backend.ClientPrefs;

class BGSprite extends FlxSprite
{
	private var idleAnim:String;
	/**
	 * Executes the `new` operation.
	 * @param image Input value for `image`.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @param scrollX Input value for `scrollX`.
	 * @param scrollY Input value for `scrollY`.
	 * @param animArray Input value for `animArray`.
	 * @param loop Input value for `loop`.
	 */
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false) {
		super(x, y);

		if (animArray != null) {
			frames = Paths.getSparrowAtlas(image);
			for (i in 0...animArray.length) {
				var anim:String = animArray[i];
				animation.addByPrefix(anim, anim, 24, loop);
				if(idleAnim == null) {
					idleAnim = anim;
					animation.play(anim);
				}
			}
		} else {
			if(image != null) {
				loadGraphic(Paths.image(image));
			}
			active = false;
		}
		scrollFactor.set(scrollX, scrollY);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	/**
	 * Executes the `dance` operation.
	 * @param forceplay Input value for `forceplay`.
	 * @return Result produced by `dance`, when applicable.
	 */
	public function dance(?forceplay:Bool = false) {
		if(idleAnim != null) {
			animation.play(idleAnim, forceplay);
		}
	}
}