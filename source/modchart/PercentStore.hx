package modchart;

using StringTools;

/**
 * Modifier percent storage: one value per modifier per player.
 *
 * Names are case-insensitive (NotITG/FunkinModchart parity: `Drunk`,
 * `drunk` and `DRUNK` are the same mod). Lane-specific variants are just
 * longer names (`drunk0`, `drunkX`, ...) — modifiers sum the base and the
 * lane-suffixed percents themselves via `Modifier.getPercent`.
 */
class PercentStore
{
	public static final PLAYER_COUNT:Int = 2;

	var percents:Map<String, Array<Float>> = new Map();

	public function new()
	{
	}

	public static function normalize(name:String):String
	{
		return name == null ? '' : name.toLowerCase().trim();
	}

	public function set(name:String, value:Float, player:Int = -1):Void
	{
		final key:String = normalize(name);
		if (key.length == 0)
			return;
		var values:Array<Float> = percents.get(key);
		if (values == null)
		{
			values = [0, 0];
			percents.set(key, values);
		}
		if (player < 0)
		{
			for (i in 0...values.length)
				values[i] = value;
		}
		else if (player < values.length)
		{
			values[player] = value;
		}
	}

	public function get(name:String, player:Int):Float
	{
		final values:Array<Float> = percents.get(normalize(name));
		if (values == null || player < 0 || player >= values.length)
			return 0;
		return values[player];
	}

	public function has(name:String):Bool
	{
		return percents.exists(normalize(name));
	}

	public function clear():Void
	{
		percents.clear();
	}

	/** True when every stored percent is zero (fast path for the adapter). */
	public function isIdle():Bool
	{
		for (values in percents)
		{
			for (value in values)
			{
				if (value != 0)
					return false;
			}
		}
		return true;
	}

	public function names():Array<String>
	{
		final out:Array<String> = [];
		for (name in percents.keys())
			out.push(name);
		return out;
	}
}
