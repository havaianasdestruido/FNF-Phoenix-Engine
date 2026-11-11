package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Schmovin-style tornado (`schmovinTornado`). */
class SchmovinTornado extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('schmovinTornado', params.player);
		if (perc == 0)
			return pos;
		final columnShift:Float = params.lane * Math.PI / 3;
		final strumNegator:Float = (-cos(-columnShift) + 1) / 2 * 112 * 3;
		pos.x += ((-cos((params.distance / 135) - columnShift) + 1) / 2 * 112 * 3 - strumNegator) * perc;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
