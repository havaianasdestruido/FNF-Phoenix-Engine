package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Square-wave lane drift (`square`, `squareOffset/Period`). */
class Square extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final squarePerc:Float = getPercent('square', player);
		if (squarePerc == 0)
			return pos;
		final offset:Float = getPercent('squareOffset', player);
		final period:Float = getPercent('squarePeriod', player);
		final amp:Float = (Math.PI * (params.distance + offset) / (112 + (period * 112)));
		pos.x += squarePerc * squareWave(amp);
		return pos;
	}

	function squareWave(angle:Float):Float
	{
		var wrapped:Float = angle % (Math.PI * 2);
		if (wrapped < 0)
			wrapped += Math.PI * 2;
		return wrapped >= Math.PI ? -1.0 : 1.0;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
