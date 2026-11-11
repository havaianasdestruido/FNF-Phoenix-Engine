package modchart;

/** Kinds of timeline events, mirroring FunkinModchart's `EventType`. */
enum ModchartEventKind
{
	SET;
	EASE;
	ADD;
	CALLBACK;
	REPEATER;
}

/**
 * One beat-timeline event. `set` snaps a percent at `beat`, `ease`/`add`
 * tween it over `length` beats, `repeater` invokes a callback every `length`
 * beats from `beat` onward and `callback` invokes it once.
 *
 * Eases capture their starting percent lazily on the first update, per
 * player, so `player = -1` keeps each side's own start value.
 */
class ModchartEvent
{
	public var kind:ModchartEventKind = SET;
	public var name:String = '';
	public var beat:Float = 0;
	public var length:Float = 0;
	public var target:Float = 0;
	public var player:Int = -1;
	public var ease:Float->Float = ModchartEase.linear;
	public var callback:ModchartEvent->Void = null;
	public var fired:Bool = false;
	/** Song beat at the moment a callback/repeater last fired (handed to scripts). */
	public var fireBeat:Float = 0;

	// Captured starting percents for EASE/ADD, one per player.
	var entries:Array<Null<Float>> = [null, null];
	var nextRepeat:Null<Float> = null;

	public function new(kind:ModchartEventKind, beat:Float)
	{
		this.kind = kind;
		this.beat = beat;
	}

	public var startBeat(get, never):Float;

	public var endBeat(get, never):Float;

	function get_startBeat():Float
	{
		return beat;
	}

	function get_endBeat():Float
	{
		return beat + length;
	}

	/** Applies this event for the current beat. Returns true when it is done. */
	public function update(curBeat:Float, store:PercentStore):Bool
	{
		switch (kind)
		{
			case SET:
				if (curBeat >= beat && !fired)
				{
					store.set(name, target, player);
					fired = true;
				}
			case EASE:
				if (fired)
					return true;
				final progress:Float = length <= 0 ? 1 : ModchartVec3.clamp((curBeat - beat) / length, 0, 1);
				applyTween(store, progress, false);
				if (curBeat >= endBeat)
					fired = true;
			case ADD:
				if (fired)
					return true;
				final progress:Float = length <= 0 ? 1 : ModchartVec3.clamp((curBeat - beat) / length, 0, 1);
				applyTween(store, progress, true);
				if (curBeat >= endBeat)
					fired = true;
			case CALLBACK:
				if (curBeat >= beat && !fired)
				{
					fireBeat = curBeat;
					if (callback != null)
						callback(this);
					fired = true;
				}
			case REPEATER:
				if (nextRepeat == null)
					nextRepeat = beat;
				final interval:Float = length <= 0 ? 1 : length;
				// Bounded catch-up: a beat jump still fires pending repeats, but never stalls a frame.
				var guard:Int = 0;
				while (curBeat >= nextRepeat && guard < 64)
				{
					fireBeat = curBeat;
					if (callback != null)
						callback(this);
					nextRepeat += interval;
					guard++;
				}
		}
		return fired;
	}

	function applyTween(store:PercentStore, progress:Float, additive:Bool):Void
	{
		final eased:Float = ease(progress);
		if (player < 0)
		{
			for (i in 0...PercentStore.PLAYER_COUNT)
			{
				final start:Float = entry(store, i);
				store.set(name, additive ? start + target * eased : ModchartVec3.lerp(start, target, eased), i);
			}
		}
		else
		{
			final start:Float = entry(store, player);
			store.set(name, additive ? start + target * eased : ModchartVec3.lerp(start, target, eased), player);
		}
	}

	function entry(store:PercentStore, index:Int):Float
	{
		var value:Null<Float> = entries[index];
		if (value == null)
		{
			value = store.get(name, index);
			entries[index] = value;
		}
		return value;
	}
}
