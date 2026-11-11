package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Classic tornado: lanes swing in an arc as they approach (`tornado`). */
class Tornado extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final tornado:Float = getPercent('tornado', params.player);
		if (tornado == 0)
			return pos;
		final keyCount:Int = getKeyCount();
		final wideField:Bool = keyCount > 4;
		final width:Int = wideField ? 4 : 3;
		var startCol:Int = params.lane - width;
		var endCol:Int = params.lane + width;
		startCol = Math.round(ModchartVec3.clamp(startCol, 0, keyCount));
		endCol = Math.round(ModchartVec3.clamp(endCol, 0, keyCount));
		final xOffset:Float = (112 * 1.5) - (112 * params.lane);
		final minX:Float = -xOffset;
		final maxX:Float = xOffset;
		final between:Float = scale(xOffset, minX, maxX, -1, 1);
		var rads:Float = Math.acos(ModchartVec3.clamp(between, -1, 1));
		rads += (params.distance * 0.8) * 6 / getScreenHeight();
		final adjusted:Float = scale(cos(rads), -1, 1, minX, maxX);
		pos.x -= (adjusted - xOffset) * tornado;
		return pos;
	}

	inline function scale(x:Float, l1:Float, h1:Float, l2:Float, h2:Float):Float
	{
		return (x - l1) * (h2 - l2) / (h1 - l1) + l2;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
