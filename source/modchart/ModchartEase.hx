package modchart;

using StringTools;

/**
 * Named easing functions for the modchart event timeline, keyed by the same
 * strings scripts use (`'sineInOut'`, `'quadOut'`, ... — see
 * `LuaUtils.getFlxEaseByString`). Pure `Float -> Float` so the core stays
 * Flixel-free; the Lua/Python adapters resolve names through here (or through
 * `FlxEase`, whose functions share the signature).
 */
class ModchartEase
{
	public static function byName(name:String):Float->Float
	{
		if (name == null)
			return linear;
		return switch (name.toLowerCase().trim())
		{
			case 'backin': backIn;
			case 'backinout': backInOut;
			case 'backout': backOut;
			case 'bouncein': bounceIn;
			case 'bounceinout': bounceInOut;
			case 'bounceout': bounceOut;
			case 'circin': circIn;
			case 'circinout': circInOut;
			case 'circout': circOut;
			case 'cubein': cubeIn;
			case 'cubeinout': cubeInOut;
			case 'cubeout': cubeOut;
			case 'elasticin': elasticIn;
			case 'elasticinout': elasticInOut;
			case 'elasticout': elasticOut;
			case 'expoin': expoIn;
			case 'expoinout': expoInOut;
			case 'expoout': expoOut;
			case 'quadin': quadIn;
			case 'quadinout': quadInOut;
			case 'quadout': quadOut;
			case 'quartin': quartIn;
			case 'quartinout': quartInOut;
			case 'quartout': quartOut;
			case 'quintin': quintIn;
			case 'quintinout': quintInOut;
			case 'quintout': quintOut;
			case 'sinein': sineIn;
			case 'sineinout': sineInOut;
			case 'sineout': sineOut;
			case 'smoothstepin': smoothStepIn;
			case 'smoothstepinout': smoothStepInOut;
			case 'smoothstepout': smoothStepOut;
			case 'smootherstepin': smootherStepIn;
			case 'smootherstepinout': smootherStepInOut;
			case 'smootherstepout': smootherStepOut;
			case _: linear;
		}
	}

	public static function linear(t:Float):Float
	{
		return t;
	}

	public static function sineIn(t:Float):Float
	{
		return 1 - Math.cos(t * Math.PI / 2);
	}

	public static function sineOut(t:Float):Float
	{
		return Math.sin(t * Math.PI / 2);
	}

	public static function sineInOut(t:Float):Float
	{
		return -(Math.cos(Math.PI * t) - 1) / 2;
	}

	public static function quadIn(t:Float):Float
	{
		return t * t;
	}

	public static function quadOut(t:Float):Float
	{
		return t * (2 - t);
	}

	public static function quadInOut(t:Float):Float
	{
		return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
	}

	public static function cubeIn(t:Float):Float
	{
		return t * t * t;
	}

	public static function cubeOut(t:Float):Float
	{
		final u:Float = t - 1;
		return u * u * u + 1;
	}

	public static function cubeInOut(t:Float):Float
	{
		return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
	}

	public static function quartIn(t:Float):Float
	{
		return t * t * t * t;
	}

	public static function quartOut(t:Float):Float
	{
		final u:Float = t - 1;
		return 1 - u * u * u * u;
	}

	public static function quartInOut(t:Float):Float
	{
		return t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (t - 1) * (t - 1) * (t - 1) * (t - 1);
	}

	public static function quintIn(t:Float):Float
	{
		return t * t * t * t * t;
	}

	public static function quintOut(t:Float):Float
	{
		final u:Float = t - 1;
		return 1 + u * u * u * u * u;
	}

	public static function quintInOut(t:Float):Float
	{
		return t < 0.5 ? 16 * t * t * t * t * t : 1 + 16 * (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1);
	}

	public static function expoIn(t:Float):Float
	{
		return t == 0 ? 0 : Math.pow(2, 10 * (t - 1));
	}

	public static function expoOut(t:Float):Float
	{
		return t == 1 ? 1 : 1 - Math.pow(2, -10 * t);
	}

	public static function expoInOut(t:Float):Float
	{
		if (t == 0)
			return 0;
		if (t == 1)
			return 1;
		return t < 0.5 ? Math.pow(2, 20 * t - 10) / 2 : (2 - Math.pow(2, -20 * t + 10)) / 2;
	}

	public static function circIn(t:Float):Float
	{
		return 1 - Math.sqrt(1 - t * t);
	}

	public static function circOut(t:Float):Float
	{
		final u:Float = t - 1;
		return Math.sqrt(1 - u * u);
	}

	public static function circInOut(t:Float):Float
	{
		return t < 0.5 ? (1 - Math.sqrt(1 - 4 * t * t)) / 2 : (Math.sqrt(1 - (2 * t - 2) * (2 * t - 2)) + 1) / 2;
	}

	public static function backIn(t:Float):Float
	{
		final c:Float = 1.70158;
		return t * t * ((c + 1) * t - c);
	}

	public static function backOut(t:Float):Float
	{
		final c:Float = 1.70158;
		final u:Float = t - 1;
		return 1 + (c + 1) * u * u * u + c * u * u;
	}

	public static function backInOut(t:Float):Float
	{
		final c:Float = 1.70158 * 1.525;
		return t < 0.5 ? (t * t * ((c + 1) * t - c)) / 2 : ((t - 2) * (t - 2) * ((c + 1) * t - c) + 2) / 2;
	}

	public static function bounceOut(t:Float):Float
	{
		if (t < 1 / 2.75)
			return 7.5625 * t * t;
		if (t < 2 / 2.75)
		{
			final u:Float = t - 1.5 / 2.75;
			return 7.5625 * u * u + 0.75;
		}
		if (t < 2.5 / 2.75)
		{
			final u:Float = t - 2.25 / 2.75;
			return 7.5625 * u * u + 0.9375;
		}
		final u:Float = t - 2.625 / 2.75;
		return 7.5625 * u * u + 0.984375;
	}

	public static function bounceIn(t:Float):Float
	{
		return 1 - bounceOut(1 - t);
	}

	public static function bounceInOut(t:Float):Float
	{
		return t < 0.5 ? bounceIn(t * 2) / 2 : bounceOut(t * 2 - 1) / 2 + 0.5;
	}

	public static function elasticOut(t:Float):Float
	{
		if (t == 0)
			return 0;
		if (t == 1)
			return 1;
		return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3)) + 1;
	}

	public static function elasticIn(t:Float):Float
	{
		if (t == 0)
			return 0;
		if (t == 1)
			return 1;
		return -Math.pow(2, 10 * (t - 1)) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3));
	}

	public static function elasticInOut(t:Float):Float
	{
		if (t == 0)
			return 0;
		if (t == 1)
			return 1;
		return t < 0.5 ? elasticIn(t * 2) / 2 : elasticOut(t * 2 - 1) / 2 + 0.5;
	}

	public static function smoothStepIn(t:Float):Float
	{
		return t * t * t;
	}

	public static function smoothStepOut(t:Float):Float
	{
		final u:Float = t - 1;
		return u * u * u + 1;
	}

	public static function smoothStepInOut(t:Float):Float
	{
		return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
	}

	public static function smootherStepIn(t:Float):Float
	{
		return t * t * t * t * (t * 6 - 15) + 10 * t * t * t;
	}

	public static function smootherStepOut(t:Float):Float
	{
		return 1 - smootherStepIn(1 - t);
	}

	public static function smootherStepInOut(t:Float):Float
	{
		return t < 0.5 ? smootherStepIn(t * 2) / 2 : smootherStepOut(t * 2 - 1) / 2 + 0.5;
	}
}
