package modchart;

/**
 * FunkinModchart-style manager: owns the playfields and exposes the script
 * API (`addModifier`, `setPercent`, `set`/`ease`/`add`, `callback`,
 * `repeater`, `addPlayfield`). Renderer-free — `PlayStateModchart` drives
 * `update` once per frame and applies `transform` to the live sprites.
 */
class ModchartManager
{
	public var playfields:Array<PlayField> = [];

	public function new()
	{
		playfields.push(new PlayField());
	}

	public function addPlayfield():PlayField
	{
		final field:PlayField = new PlayField();
		playfields.push(field);
		return field;
	}

	public function playfield(field:Int):PlayField
	{
		if (field < 0 || field >= playfields.length)
			return null;
		return playfields[field];
	}

	function eachField(field:Int, func:PlayField->Void):Void
	{
		if (field >= 0)
		{
			final target:PlayField = playfield(field);
			if (target != null)
				func(target);
			return;
		}
		for (target in playfields)
			func(target);
	}

	public function addModifier(name:String, field:Int = -1):Bool
	{
		var added:Bool = false;
		eachField(field, function(pf:PlayField) {
			if (pf.addModifier(name))
				added = true;
		});
		return added;
	}

	public function setPercent(name:String, value:Float, player:Int = -1, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.setPercent(name, value, player));
	}

	public function getPercent(name:String, player:Int = 0, field:Int = 0):Float
	{
		final target:PlayField = playfield(field);
		return target == null ? 0 : target.getPercent(name, player);
	}

	public function set(name:String, beat:Float, value:Float, player:Int = -1, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.set(name, beat, value, player));
	}

	public function ease(name:String, beat:Float, length:Float, value:Float = 1, ease:Float->Float = null, player:Int = -1, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.ease(name, beat, length, value, ease, player));
	}

	public function add(name:String, beat:Float, length:Float, addition:Float = 1, ease:Float->Float = null, player:Int = -1, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.add(name, beat, length, addition, ease, player));
	}

	public function setAdd(name:String, beat:Float, valueToAdd:Float, player:Int = -1, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.setAdd(name, beat, valueToAdd, player));
	}

	public function callback(beat:Float, callback:ModchartEvent->Void, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.callback(beat, callback));
	}

	public function repeater(beat:Float, length:Float, callback:ModchartEvent->Void, field:Int = -1):Void
	{
		eachField(field, function(pf:PlayField) pf.repeater(beat, length, callback));
	}

	public function update(curBeat:Float):Void
	{
		for (field in playfields)
			field.update(curBeat);
	}

	public function isActive():Bool
	{
		for (field in playfields)
		{
			if (field.isActive())
				return true;
		}
		return false;
	}

	public function clear():Void
	{
		for (field in playfields)
			field.clear();
	}

	public function modifierNames():Array<String>
	{
		final out:Array<String> = [];
		for (field in playfields)
		{
			for (name in field.modifierNames())
			{
				if (out.indexOf(name) == -1)
					out.push(name);
			}
		}
		return out;
	}
}
