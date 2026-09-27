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

	public function new(char:String = 'bf', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

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
			if (iconAsset == null)
				// No icon art at all (e.g. content-stripped builds ship no
				// icons/): generate a stand-in instead of crashing.
				iconAsset = getPlaceholderIcon(char);

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

	public function bounce() {
		if(canBounce) {
			var mult:Float = 1.2;
			scale.set(mult, mult);
			updateHitbox();
		}
	}

	public function playAnim(anim:String) {
		if (animation.exists(anim))
			animation.play(anim);
	}

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

	public function getCharacter():String {
		return char;
	}

	static var _placeholderIcons:Map<String, FlxGraphic> = [];

	/**
	 * Generates (and caches) a two-frame health icon stand-in: the normal frame
	 * in the character's placeholder color, the losing frame darkened.
	 * Matches the standard 150x150-per-frame icon layout.
	 */
	static function getPlaceholderIcon(char:String):FlxGraphic
	{
		if (_placeholderIcons.exists(char))
		{
			var cached:FlxGraphic = _placeholderIcons.get(char);
			// Bitmap cleanup (Paths.clearStoredMemory) can destroy or evict
			// cached graphics; drop dead entries so a fresh placeholder is
			// generated below instead of reusing a broken graphic.
			if (cached != null && cached.bitmap != null && FlxG.bitmap.get(cached.key) == cached)
				return cached;
			_placeholderIcons.remove(char);
		}

		trace('HealthIcon: no icon found for "$char", using a generated placeholder.');
		var base:FlxColor = Character.placeholderColor(char);
		var dark:FlxColor = FlxColor.fromRGB(Std.int(base.red * 0.45), Std.int(base.green * 0.45), Std.int(base.blue * 0.45));

		var pixels:BitmapData = new BitmapData(300, 150, true, 0);
		pixels.fillRect(new Rectangle(0, 0, 150, 150), base);
		pixels.fillRect(new Rectangle(150, 0, 150, 150), dark);

		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(pixels, false, 'placeholder-icon-$char');
		_placeholderIcons.set(char, graphic);
		return graphic;
	}
}
