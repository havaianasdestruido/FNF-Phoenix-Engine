package objects;

import backend.Paths;
import backend.ClientPrefs;

class BGSprite extends FlxSprite
{
	private var idleAnim:String;
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false) {
		super(x, y);

		if (animArray != null) {
			frames = Paths.getSparrowAtlas(image);
			if (frames == null) {
				// Missing atlas (e.g. stripped stage art in content-stripped
				// builds): invisible stand-in so stages keep working.
				makeGraphic(2, 2, 0, true);
				active = false;
			} else {
				for (i in 0...animArray.length) {
					var anim:String = animArray[i];
					animation.addByPrefix(anim, anim, 24, loop);
					if(idleAnim == null) {
						idleAnim = anim;
						animation.play(anim);
					}
				}
			}
		} else {
			if(image != null) {
				var loaded = Paths.image(image);
				if (loaded == null) {
					// Missing image (e.g. stripped stage art in content-stripped
					// builds): invisible stand-in so stages keep working.
					makeGraphic(2, 2, 0, true);
				} else {
					loadGraphic(loaded);
				}
			}
			active = false;
		}
		scrollFactor.set(scrollX, scrollY);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function dance(?forceplay:Bool = false) {
		if(idleAnim != null) {
			animation.play(idleAnim, forceplay);
		}
	}
}