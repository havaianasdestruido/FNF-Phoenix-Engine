package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Lemniscate path (`infinite`) — lerps arrows onto an infinity curve. */
class Infinite extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('infinite', params.player);
		if (perc == 0)
			return pos;
		final rat:Float = params.lane % 2 == 0 ? 1 : -1;
		final time:Float = (-params.distance * Math.PI * 0.001) + rat * Math.PI / 2;
		final invTransf:Float = (2 / (3 - cos(time * 2)));
		final curveX:Float = getScreenWidth() * 0.5 + invTransf * cos(time) * 580;
		final curveY:Float = getScreenHeight() * 0.5 + invTransf * (sin(time * 2) * 0.5) * 750;
		final curve:ModchartVec3 = new ModchartVec3(curveX, curveY, 0);
		return pos.lerpTo(curve, perc);
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
