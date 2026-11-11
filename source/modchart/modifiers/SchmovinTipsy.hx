package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Schmovin-style tipsy (`schmovinTipsy`). */
class SchmovinTipsy extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		pos.y += sin(params.curBeat / 4 * Math.PI + params.lane) * 56 * getPercent('schmovinTipsy', params.player);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
