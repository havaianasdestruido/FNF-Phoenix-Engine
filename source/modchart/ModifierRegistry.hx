package modchart;

import modchart.modifiers.Beat;
import modchart.modifiers.Bounce;
import modchart.modifiers.Boost;
import modchart.modifiers.Bumpy;
import modchart.modifiers.CenterRotate;
import modchart.modifiers.Confusion;
import modchart.modifiers.CounterClockWise;
import modchart.modifiers.Drugged;
import modchart.modifiers.Drunk;
import modchart.modifiers.FieldRotate;
import modchart.modifiers.Infinite;
import modchart.modifiers.Invert;
import modchart.modifiers.LocalRotate;
import modchart.modifiers.OpponentSwap;
import modchart.modifiers.Radionic;
import modchart.modifiers.ReceptorScroll;
import modchart.modifiers.Reverse;
import modchart.modifiers.Rotate;
import modchart.modifiers.SawTooth;
import modchart.modifiers.Scale;
import modchart.modifiers.SchmovinDrunk;
import modchart.modifiers.SchmovinTipsy;
import modchart.modifiers.SchmovinTornado;
import modchart.modifiers.Skew;
import modchart.modifiers.Spiral;
import modchart.modifiers.Square;
import modchart.modifiers.Stealth;
import modchart.modifiers.Tipsy;
import modchart.modifiers.Tornado;
import modchart.modifiers.Transform;
import modchart.modifiers.Vibrate;
import modchart.modifiers.Wiggle;
import modchart.modifiers.ZigZag;
import modchart.modifiers.Zoom;

/**
 * Name -> modifier class registry. Names are the FunkinModchart/NotITG mod
 * names scripts already know (`'drunk'`, `'tornado'`, `'reverse'`, ...),
 * matched case-insensitively. Unknown names return null so scripts fail
 * soft instead of crashing the song.
 */
class ModifierRegistry
{
	static var registry:Map<String, Class<Modifier>> = null;

	static function ensure():Void
	{
		if (registry != null)
			return;
		registry = new Map();
		register('beat', Beat);
		register('bounce', Bounce);
		register('boost', Boost);
		register('bumpy', Bumpy);
		register('centerrotate', CenterRotate);
		register('confusion', Confusion);
		register('counterclockwise', CounterClockWise);
		register('drugged', Drugged);
		register('drunk', Drunk);
		register('fieldrotate', FieldRotate);
		register('infinite', Infinite);
		register('invert', Invert);
		register('localrotate', LocalRotate);
		register('opponentswap', OpponentSwap);
		register('radionic', Radionic);
		register('receptorscroll', ReceptorScroll);
		register('reverse', Reverse);
		register('rotate', Rotate);
		register('sawtooth', SawTooth);
		register('scale', Scale);
		register('schmovindrunk', SchmovinDrunk);
		register('schmovintipsy', SchmovinTipsy);
		register('schmovintornado', SchmovinTornado);
		register('skew', Skew);
		register('spiral', Spiral);
		register('square', Square);
		register('stealth', Stealth);
		register('tipsy', Tipsy);
		register('tornado', Tornado);
		register('transform', Transform);
		register('vibrate', Vibrate);
		register('wiggle', Wiggle);
		register('zigzag', ZigZag);
		register('zoom', Zoom);
	}

	static function register(name:String, cls:Class<Modifier>):Void
	{
		registry.set(name, cls);
	}

	public static function create(name:String, playfield:PlayField):Modifier
	{
		ensure();
		final cls:Class<Modifier> = registry.get(PercentStore.normalize(name));
		if (cls == null)
			return null;
		return Type.createInstance(cls, [playfield]);
	}

	public static function exists(name:String):Bool
	{
		ensure();
		return registry.exists(PercentStore.normalize(name));
	}

	public static function names():Array<String>
	{
		ensure();
		final out:Array<String> = [];
		for (name in registry.keys())
			out.push(name);
		out.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}
}
