package modchart;

/**
 * Beat-sorted event list. Events are kept sorted by beat on insert, so a
 * `set`/`ease`/`callback` at a past beat still resolves in song order.
 */
class ModchartEventManager
{
	var events:Array<ModchartEvent> = [];

	public function new()
	{
	}

	public function add(event:ModchartEvent):Void
	{
		var pos:Int = events.length;
		while (pos > 0 && events[pos - 1].beat > event.beat)
			pos--;
		events.insert(pos, event);
	}

	/**
	 * Advances every event and drops the ones that finished. A copy is
	 * iterated so a callback that schedules more events (or resets the
	 * modchart) cannot corrupt the loop.
	 */
	public function update(curBeat:Float, store:PercentStore):Void
	{
		if (events.length == 0)
			return;
		for (event in events.copy())
			event.update(curBeat, store);
		var i:Int = events.length - 1;
		while (i >= 0)
		{
			final event:ModchartEvent = events[i];
			if (event.fired && event.kind != REPEATER)
				events.splice(i, 1);
			i--;
		}
	}

	public function clear():Void
	{
		events = [];
	}

	public function count():Int
	{
		return events.length;
	}

	public function list():Array<ModchartEvent>
	{
		return events;
	}
}
