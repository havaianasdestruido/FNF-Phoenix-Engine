package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Mirror lanes (`invert` swaps outer/inner, `flip` mirrors the field). */
class Invert extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final invert:Float = -(params.lane % 2 - 0.5) * 2;
		final flip:Float = (params.lane - 1.5) * -2;
		pos.x += 112 * (invert * getPercent('invert', player) + flip * getPercent('flip', player));
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
