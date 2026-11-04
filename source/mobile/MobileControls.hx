package mobile;

import flixel.util.FlxSave;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxSignal;
import mobile.flixel.FlxButton;
import mobile.flixel.FlxHitbox;
import mobile.flixel.FlxVirtualPad;

class MobileControls extends FlxSpriteGroup
{
	public static var customVirtualPad(get, set):FlxVirtualPad;
	public static var mode(get, set):String;
	public static var enabled(get, never):Bool;

	public var virtualPad:FlxVirtualPad;
	public var hitbox:FlxHitbox;

	public static var save:MobileControlsSave = null;

	public function new()
	{
		super();

		if (save == null) {
			save = new MobileControlsSave();
			save.load();
		}

		switch (MobileControls.mode)
		{
			case 'Pad-Right':
				virtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Left':
				virtualPad = new FlxVirtualPad(LEFT_FULL, NONE, ClientPrefs.mobileCEx);
				add(virtualPad);
			case 'Pad-Custom':
				virtualPad = MobileControls.customVirtualPad;
				add(virtualPad);
			case 'Hitbox':
				hitbox = new FlxHitbox(4, Std.int(FlxG.width / 4), FlxG.height, [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000]);
				add(hitbox);
		}
	}

	/**
	 * Sets the camera that draws the mobile controls and that their touch input is checked on.
	 *
	 * Flixel only forwards `cameras` to the direct members of a sprite group, so the buttons living
	 * inside `hitbox`/`virtualPad` would keep a `null` cameras list. In that case they are drawn and
	 * hit-tested on the default draw target (the gameplay camera), scrolling along with it.
	 *
	 * @param value The cameras the mobile controls should use.
	 */
	override function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		if (hitbox != null)
			hitbox.cameras = value;

		if (virtualPad != null)
			virtualPad.cameras = value;

		return super.set_cameras(value);
	}

	override public function destroy():Void
	{
		super.destroy(); // Children own their resize listeners; avoid destroying twice.
		virtualPad = null;
		hitbox = null;
	}

	private static function get_mode():String
	{
		return MobileControlsSave.instance.mobileCMode;
	}

	private static function set_mode(mode:String = 'Hitbox'):String
	{
		MobileControlsSave.instance.mobileCMode = mode;
		MobileControlsSave.instance.save();

		return mode;
	}

	private static function get_customVirtualPad():FlxVirtualPad
	{
		var virtualPad:FlxVirtualPad = new FlxVirtualPad(RIGHT_FULL, NONE, ClientPrefs.mobileCEx);
		if (MobileControlsSave.instance.buttons == null)
			return virtualPad;

		var tempCount:Int = 0;
		final savedWidth:Int = MobileControlsSave.instance.buttonsWidth == 0 ? ScreenLayout.BASE_WIDTH : Std.int(MobileControlsSave.instance.buttonsWidth);
		for (button in virtualPad)
		{
			if (tempCount < MobileControlsSave.instance.buttons.length && MobileControlsSave.instance.buttons[tempCount] != null)
			{
				button.x = ScreenLayout.anchoredPosition(MobileControlsSave.instance.buttons[tempCount].x, savedWidth, FlxG.width, button.width);
				button.y = MobileControlsSave.instance.buttons[tempCount].y;
			}
			tempCount++;
		}

		return virtualPad;
	}

	private static function set_customVirtualPad(virtualPad:FlxVirtualPad):FlxVirtualPad
	{
		MobileControlsSave.instance.buttons = [for (button in virtualPad) FlxPoint.get(button.x, button.y)];
		// Legacy saves without this field were authored in the 1280-wide viewport.
		MobileControlsSave.instance.buttonsWidth = FlxG.width;
		MobileControlsSave.instance.save();
		return virtualPad;
	}

	private static function get_enabled():Bool
		return ClientPrefs.mobileCAlpha >= 0.1;
}
