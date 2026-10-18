package backend;

import flixel.input.keyboard.FlxKey;

/**
 * Hardware triggers (non-standard device buttons such as the Android volume
 * rocker) stored in the regular keybind map, next to keyboard keys.
 *
 * Keyboard keys are never negative (they are SDL/Lime keycodes), so a hardware
 * key code `c` is stored as `-(OFFSET + c)`. Such values can't clash with a
 * keyboard binding and are never handed to FlxG.keys: consumers must check
 * `isBind` first.
 */
class HardwareKeys
{
	/** Android KeyEvent keycodes for the volume rocker (see AndroidHardwareInput). */
	public static inline final KEYCODE_VOLUME_UP:Int = 24;
	public static inline final KEYCODE_VOLUME_DOWN:Int = 25;

	static inline final OFFSET:Int = 0x10000;

	/** Encodes a hardware key code as a keybind value. */
	public static inline function toBind(keyCode:Int):FlxKey
		return cast -(OFFSET + keyCode);

	/** True when the keybind value refers to a hardware trigger. */
	public static inline function isBind(key:FlxKey):Bool
	{
		var value:Int = cast key;
		return value < 0;
	}

	/** Decodes a keybind value produced by `toBind` back into the hardware key code. */
	public static function keyCodeOf(key:FlxKey):Int
	{
		var value:Int = cast key;
		return -value - OFFSET;
	}

	/** Human readable label for the options menu. */
	public static function getName(key:FlxKey):String
	{
		var keyCode:Int = keyCodeOf(key);
		if (keyCode == KEYCODE_VOLUME_UP)
			return 'VOL_UP';
		if (keyCode == KEYCODE_VOLUME_DOWN)
			return 'VOL_DOWN';
		return 'HW_' + keyCode;
	}
}
