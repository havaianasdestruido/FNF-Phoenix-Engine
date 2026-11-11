package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Random jitter (`vibrate`). Uses `Math.random`, so it is intentionally non-deterministic. */
class Vibrate extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final vib:Float = getPercent('vibrate', params.player);
		pos.x += (Math.random() - 0.5) * vib * 20;
		pos.y += (Math.random() - 0.5) * vib * 20;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return getPercent('vibrate', params.player) != 0;
	}
}
