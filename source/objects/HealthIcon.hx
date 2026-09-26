package objects;

import flixel.graphics.FlxGraphic;
import backend.Paths;
import backend.ClientPrefs;
import backend.CoolUtil;
import play.PlayState;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var canBounce:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	var initialWidth:Float = 0;
	var initialHeight:Float = 0;

	/**
	 * Executes the `new` operation.
	 * @param char Input value for `char`.
	 * @param isPlayer Input value for `isPlayer`.
	 * @param allowGPU Input value for `allowGPU`.
	 */
	public function new(char:String = 'bf', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);

		if(canBounce) {
			var mult:Float = FlxMath.lerp(1, scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
			scale.set(mult, mult);
			updateHitbox();
		}
	}

	public var iconOffsets:Array<Float> = [0, 0];
	/**
	 * Executes the `changeIcon` operation.
	 * @param char Input value for `char`.
	 * @return Result produced by `changeIcon`, when applicable.
	 */
	public function changeIcon(char:String) {
		if(this.char != char) {
			if (char.length < 1)
				char = 'face';

			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			var iconAsset:FlxGraphic = FlxG.bitmap.add(Paths.image(name));

			if (iconAsset == null)
				iconAsset = Paths.image('icons/icon-face');
			else if (!Paths.fileExists('images/icons/icon-face.png', IMAGE))
				trace("Warning: could not find the placeholder icon, expect crashes!");

			//cleaned up to be less confusing. also floor is used so iSize has to definitively be 3 to use winning icons
			final iSize:Float = Math.round(iconAsset.width / iconAsset.height);
			initialWidth = iconAsset.width;
			initialHeight = iconAsset.height;
			loadGraphic(iconAsset, true, Math.floor(iconAsset.width / iSize), Math.floor(iconAsset.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);

			// animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			antialiasing = (ClientPrefs.globalAntialiasing);
			if(char.endsWith('-pixel')) {
				antialiasing = false;
			}
		}
	}

	/**
	 * Executes the `bounce` operation.
	 * @return Result produced by `bounce`, when applicable.
	 */
	public function bounce() {
		if(canBounce) {
			var mult:Float = 1.2;
			scale.set(mult, mult);
			updateHitbox();
		}
	}

	/**
	 * Executes the `playAnim` operation.
	 * @param anim Input value for `anim`.
	 * @return Result produced by `playAnim`, when applicable.
	 */
	public function playAnim(anim:String) {
		if (animation.exists(anim))
			animation.play(anim);
	}

	/**
	 * Executes the `updateHitbox` operation.
	 * @return Result produced by `updateHitbox`, when applicable.
	 */
	override function updateHitbox()
	{
		if (ClientPrefs.iconBounceType != 'Golden Apple' && ClientPrefs.iconBounceType != 'Dave and Bambi' || !Std.isOfType(FlxG.state, PlayState))
		{
			super.updateHitbox();
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		} else {
			super.updateHitbox();
			if (initialWidth != (150 * animation.numFrames) || initialHeight != 150) //Fixes weird icon offsets when they're HUMONGUS (sussy)
			{
				offset.x = iconOffsets[0];
				offset.y = iconOffsets[1];
			}
		}
	}

	/**
	 * Executes the `getCharacter` operation.
	 * @return Result produced by `getCharacter`, when applicable.
	 */
	public function getCharacter():String {
		return char;
	}
}
