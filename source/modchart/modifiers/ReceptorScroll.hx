package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Ping-pong scroll between the top and bottom of the screen (`receptorScroll`). */
class ReceptorScroll extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('receptorScroll', params.player);
		if (perc == 0)
			return pos;
		final moveSpeed:Float = getCrochet() * 4;
		if (moveSpeed == 0)
			return pos;
		final diff:Float = -params.distance;
		final vDiff:Float = -(diff - params.songTime) / moveSpeed;
		final reversed:Bool = Math.floor(vDiff) % 2 == 0;
		final startY:Float = pos.y;
		final revPerc:Float = reversed ? 1 - vDiff % 1 : vDiff % 1;
		final upscrollOffset:Float = 50;
		final downscrollOffset:Float = getScreenHeight() - 150;
		final endY:Float = upscrollOffset + ((downscrollOffset - 56) * revPerc) + 56;
		pos.y = ModchartVec3.lerp(startY, endY, perc);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
