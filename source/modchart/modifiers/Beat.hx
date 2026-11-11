package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Per-beat pulse along an axis (`beat`, `beatX/Y/Z`, `beatSpeed/Offset/Mult`). */
class Beat extends Modifier
{
	public function new(pf)
	{
		super(pf);
		for (axis in ['x', 'y', 'z', ''])
			setPercent('beat' + axis + 'Speed', 1, -1);
	}

	static final ACCEL_TIME:Float = 0.2;
	static final TOTAL_TIME:Float = 0.5;

	inline function beatMath(params:ModchartParams, offset:Float, mult:Float, speed:Float):Float
	{
		var beat:Float = ((params.curBeat * speed) + offset) + ACCEL_TIME;
		if (beat <= 0)
			return 0;
		final evenBeat:Bool = Std.int(beat) % 2 != 0;
		beat = (beat % 1 + 1) % 1;
		if (beat >= TOTAL_TIME)
			return 0;
		var amount:Float;
		if (beat < ACCEL_TIME)
			amount = Math.pow(beat / ACCEL_TIME, 2);
		else
		{
			final scaled:Float = beat / TOTAL_TIME;
			amount = (1 - scaled) * (1 + scaled);
		}
		if (evenBeat)
			amount *= -1;
		return 20 * amount * cos(params.distance * 0.01 * mult);
	}

	function computeBeat(pos:ModchartVec3, params:ModchartParams, axis:String, realAxis:String):Void
	{
		final player:Int = params.player;
		final amount:Float = getPercent('beat' + axis, player) + getPercent('beat' + axis + params.lane, player);
		if (amount == 0)
			return;
		final speed:Float = getPercent('beat' + axis + 'Speed', player);
		final offset:Float = getPercent('beat' + axis + 'Offset', player);
		final mult:Float = getPercent('beat' + axis + 'Mult', player);
		final shift:Float = beatMath(params, offset, 1 + mult, speed) * amount;
		switch (realAxis)
		{
			case 'x': pos.x += shift;
			case 'y': pos.y += shift;
			case 'z': pos.z += shift;
		}
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		computeBeat(pos, params, '', 'x');
		computeBeat(pos, params, 'x', 'x');
		computeBeat(pos, params, 'y', 'y');
		computeBeat(pos, params, 'z', 'z');
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
