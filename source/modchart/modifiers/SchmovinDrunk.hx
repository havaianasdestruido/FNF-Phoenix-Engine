package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Schmovin-style drunk (`schmovinDrunk`). */
class SchmovinDrunk extends Modifier
{
	static final THIRD:Float = 1 / 222;

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final phaseShift:Float = params.lane * 0.5 + (params.distance * THIRD) * Math.PI;
		pos.x += sin(params.curBeat * 0.25 * Math.PI + phaseShift) * 56 * getPercent('schmovinDrunk', params.player);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
