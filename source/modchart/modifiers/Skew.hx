package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Shear (`skewX`, `skewY`). Carried in visuals; Flixel sprites have no skew, so the adapter documents it as stored-only. */
class Skew extends Modifier
{
	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		final player:Int = params.player;
		data.skewX += getPercent('skewX', player) + getPercent('skewX' + params.lane, player);
		data.skewY += getPercent('skewY', player) + getPercent('skewY' + params.lane, player);
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
