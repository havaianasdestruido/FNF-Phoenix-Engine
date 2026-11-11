package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Spiral path (`spiral`, `spiralDist`). */
class Spiral extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final perc:Float = getPercent('spiral', player);
		if (perc == 0)
			return pos;
		final centerX:Float = getScreenWidth() * 0.5;
		final centerY:Float = getScreenHeight() * 0.5;
		final crochet:Float = getCrochet() == 0 ? 600 : getCrochet();
		final radius:Float = -params.distance * 0.25 + getPercent('spiralDist', player) * params.lane;
		final outX:Float = centerX + cos(-params.distance / crochet * Math.PI + params.curBeat * (Math.PI * 0.25)) * radius;
		final outY:Float = centerY + sin(-params.distance / crochet * Math.PI - params.curBeat * (Math.PI * 0.25)) * radius;
		return pos.lerpTo(new ModchartVec3(outX, outY, radius / (centerY * 4) - 1), perc);
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return getPercent('spiral', params.player) != 0;
	}
}
