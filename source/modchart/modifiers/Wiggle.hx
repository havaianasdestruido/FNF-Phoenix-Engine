package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Gentle beat wiggle (`wiggle`) — also nudges `rotateZ`. */
class Wiggle extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final wiggle:Float = getPercent('wiggle', params.player);
		pos.x += sin(params.curBeat) * wiggle * 20;
		pos.y += sin(params.curBeat + 1) * wiggle * 20;
		setPercent('rotateZ', (sin(params.curBeat) * 0.2 * wiggle) * 57.29578, params.player);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return getPercent('wiggle', params.player) != 0;
	}
}
