package flixel.util;
abstract FlxColor(Int) from Int to Int {
	public var alphaFloat(get, set):Float;
	inline function get_alphaFloat():Float return ((this >>> 24) & 0xff) / 255;
	inline function set_alphaFloat(value:Float):Float {
		this = (this & 0xffffff) | (Std.int(value * 255) << 24);
		return value;
	}
}
