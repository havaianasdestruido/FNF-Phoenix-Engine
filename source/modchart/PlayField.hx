package modchart;

/**
 * One playfield: a percent store, a beat event timeline and an ordered
 * modifier chain. The manager owns one or more playfields (FunkinModchart
 * parity); scripts target them by index (`field = 0` by default, `-1` = all).
 *
 * The playfield is renderer-free: `transform` maps a base position plus
 * per-arrow params to a modified position + visuals. The adapter in
 * `play.helpers.PlayStateModchart` feeds it strum/note data and writes the
 * result back to the sprites.
 */
class PlayField
{
	public var percents:PercentStore = new PercentStore();
	public var events:ModchartEventManager = new ModchartEventManager();
	public var modifiers:Array<Modifier> = [];

	/** Filled in by the adapter: receptor layout + song clock. */
	public var keyCount:Int = 4;
	public var screenWidth:Float = 1280;
	public var screenHeight:Float = 720;
	public var scrollSpeed:Float = 0.45;
	public var crochet:Float = 600;
	public var downscroll:Bool = false;
	public var receptorX:Array<Array<Float>> = [[], []];
	public var receptorY:Array<Array<Float>> = [[], []];

	/** Perspective projection (identity while every z stays 0). */
	public var usePerspective:Bool = true;
	public var fov:Float = Math.PI / 2;
	public var zScale:Float = 1;

	// Reused so the per-note projection does not allocate an origin each frame.
	var projectOrigin:ModchartVec3 = new ModchartVec3();

	public function new()
	{
	}

	public function addModifier(name:String):Bool
	{
		final key:String = PercentStore.normalize(name);
		for (mod in modifiers)
		{
			if (PercentStore.normalize(modifierName(mod)) == key)
				return false;
		}
		final created:Modifier = ModifierRegistry.create(key, this);
		if (created == null)
			return false;
		modifiers.push(created);
		return true;
	}

	public function addModifierInstance(name:String, instance:Modifier):Void
	{
		modifiers.push(instance);
	}

	public function hasModifier(name:String):Bool
	{
		final key:String = PercentStore.normalize(name);
		for (mod in modifiers)
		{
			if (PercentStore.normalize(modifierName(mod)) == key)
				return true;
		}
		return false;
	}

	public function modifierNames():Array<String>
	{
		final out:Array<String> = [];
		for (mod in modifiers)
			out.push(modifierName(mod));
		return out;
	}

	static function modifierName(mod:Modifier):String
	{
		final className:String = Type.getClassName(Type.getClass(mod));
		return className.substring(className.lastIndexOf('.') + 1);
	}

	public function setPercent(name:String, value:Float, player:Int = -1):Void
	{
		percents.set(name, value, player);
	}

	public function getPercent(name:String, player:Int):Float
	{
		return percents.get(name, player);
	}

	public function set(name:String, beat:Float, value:Float, player:Int = -1):Void
	{
		final event:ModchartEvent = new ModchartEvent(SET, beat);
		event.name = PercentStore.normalize(name);
		event.target = value;
		event.player = player;
		events.add(event);
	}

	public function ease(name:String, beat:Float, length:Float, value:Float = 1, ease:Float->Float = null, player:Int = -1):Void
	{
		final event:ModchartEvent = new ModchartEvent(EASE, beat);
		event.name = PercentStore.normalize(name);
		event.length = length;
		event.target = value;
		event.player = player;
		event.ease = ease == null ? ModchartEase.linear : ease;
		events.add(event);
	}

	public function add(name:String, beat:Float, length:Float, addition:Float = 1, ease:Float->Float = null, player:Int = -1):Void
	{
		final event:ModchartEvent = new ModchartEvent(ADD, beat);
		event.name = PercentStore.normalize(name);
		event.length = length;
		event.target = addition;
		event.player = player;
		event.ease = ease == null ? ModchartEase.linear : ease;
		events.add(event);
	}

	public function setAdd(name:String, beat:Float, valueToAdd:Float, player:Int = -1):Void
	{
		final base:Float = getPercent(name, player < 0 ? 0 : player);
		set(name, beat, base + valueToAdd, player);
	}

	public function callback(beat:Float, callback:ModchartEvent->Void):Void
	{
		final event:ModchartEvent = new ModchartEvent(CALLBACK, beat);
		event.callback = callback;
		events.add(event);
	}

	public function repeater(beat:Float, length:Float, callback:ModchartEvent->Void):Void
	{
		final event:ModchartEvent = new ModchartEvent(REPEATER, beat);
		event.length = length;
		event.callback = callback;
		events.add(event);
	}

	public function update(curBeat:Float):Void
	{
		events.update(curBeat, percents);
	}

	public function getReceptorX(lane:Int, player:Int):Float
	{
		if (player >= 0 && player < receptorX.length && lane >= 0 && lane < receptorX[player].length)
			return receptorX[player][lane];
		return screenWidth * 0.5;
	}

	public function getReceptorY(lane:Int, player:Int):Float
	{
		if (player >= 0 && player < receptorY.length && lane >= 0 && lane < receptorY[player].length)
			return receptorY[player][lane];
		return screenHeight * 0.5;
	}

	/**
	 * Runs the modifier chain over `pos`. `out` is reused when supplied so
	 * the per-frame adapter loop does not allocate.
	 */
	public function transform(pos:ModchartVec3, params:ModchartParams, ?out:ModchartOutput = null):ModchartOutput
	{
		if (out == null)
		{
			out = new ModchartOutput();
			out.pos.copyFrom(pos);
			out.visuals.reset();
		}
		else if (out.pos != pos)
		{
			out.pos.copyFrom(pos);
		}

		for (mod in modifiers)
		{
			if (!mod.shouldRun(params))
				continue;
			out.pos = mod.render(out.pos, params);
			out.visuals = mod.visuals(out.visuals, params);
		}

		if (usePerspective && out.pos.z != 0)
		{
			out.pos.z *= 0.001 * zScale;
			projectOrigin.set(screenWidth * 0.5, screenHeight * 0.5, 0);
			out.pos = ModchartVec3.project(out.pos, projectOrigin, fov);
		}
		return out;
	}

	/** True while a modifier is installed or the timeline still has events (the adapter's fast path). */
	public function isActive():Bool
	{
		return modifiers.length > 0 || events.count() > 0;
	}

	public function clear():Void
	{
		percents.clear();
		events.clear();
		modifiers = [];
	}
}
