package flixel.util;

/** Packed ARGB colour stand-in (the real one is the same Int abstract). */
abstract FlxColor(Int) from Int to Int
{
	public static inline var WHITE:FlxColor = 0xFFFFFFFF;
	public static inline var BLACK:FlxColor = 0xFF000000;
	public static inline var RED:FlxColor = 0xFFFF0000;

	public inline function new(value:Int = 0)
	{
		this = value;
	}
}
