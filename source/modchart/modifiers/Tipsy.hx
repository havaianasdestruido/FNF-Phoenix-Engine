package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Song-time sine wobble, slower and wider than `drunk` (`tipsy`, `tipsyX/Y/Z`, `tipsySpeed/Offset`). */
class Tipsy extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final xVal:Float = getPercent('tipsyX', player);
		final yVal:Float = getPercentLane('tipsy', params.lane, player) + getPercent('tipsyY', player);
		final zVal:Float = getPercent('tipsyZ', player);
		if (xVal == 0 && yVal == 0 && zVal == 0)
			return pos;
		final speed:Float = getPercent('tipsySpeed', player);
		final offset:Float = getPercent('tipsyOffset', player);
		final tipsy:Float = cos(params.songTime * 0.001 * ((speed * 1.2) + 1.2) + params.lane * ((offset * 1.8) + 1.8)) * 44.8;
		pos.x += tipsy * xVal;
		pos.y += tipsy * yVal;
		pos.z += tipsy * zVal;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
