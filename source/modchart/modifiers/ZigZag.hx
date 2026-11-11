package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Triangle-wave lane drift (`zigZag`). */
class ZigZag extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final zigzag:Float = getPercent('zigZag', params.player);
		if (zigzag == 0)
			return pos;
		final theta:Float = -params.distance / 112 * Math.PI;
		final outRelative:Float = Math.acos(cos(theta + Math.PI / 2)) / Math.PI * 2 - 1;
		pos.x += outRelative * 56 * zigzag;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
