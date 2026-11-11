package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Slides each side toward the other (`opponentSwap`). */
class OpponentSwap extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('opponentSwap', params.player);
		if (perc == 0)
			return pos;
		final distX:Float = getScreenWidth() * 0.5;
		pos.x -= distX * ModchartVec3.sign((params.player + 1) * 2 - 3) * perc;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
