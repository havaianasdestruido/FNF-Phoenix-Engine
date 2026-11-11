package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Counter-clockwise orbit (`counterClockWise`). */
class CounterClockWise extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('counterClockWise', params.player);
		if (perc == 0)
			return pos;
		final strumTime:Float = params.songTime + params.distance;
		final centerX:Float = getScreenWidth() * 0.5;
		final centerY:Float = getScreenHeight() * 0.5;
		final radiusOffset:Float = 112 * (params.lane - 1.5);
		final crochet:Float = getCrochet() == 0 ? 600 : getCrochet();
		final radius:Float = 200 + radiusOffset * cos(strumTime / crochet * 0.25 / 16 * Math.PI);
		final outX:Float = centerX + cos(strumTime / crochet / 4 * Math.PI) * radius;
		final outY:Float = centerY + sin(strumTime / crochet / 4 * Math.PI) * radius;
		return pos.lerpTo(new ModchartVec3(outX, outY, 0), perc);
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return getPercent('counterClockWise', params.player) != 0;
	}
}
