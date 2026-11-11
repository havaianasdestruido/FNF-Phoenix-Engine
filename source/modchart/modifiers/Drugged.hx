package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Layered-sine wobble (`drugged`) — position plus a touch of spin. */
class Drugged extends Modifier
{
	function wobble(x:Float, t:Float):Float
	{
		var y:Float = sin(x);
		y += sin(x * 2.1 + t) * 4.5;
		y += sin(x * 1.72 + t * 1.121) * 4.0;
		y += sin(x * 2.221 + t * 0.437) * 5.0;
		y += sin(x * 3.1122 + t * 4.269) * 2.5;
		return y * 0.06;
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final x:Float = (params.distance * 0.009) + (params.lane * 0.125);
		final t:Float = 0.01 * (-params.songTime * 0.0025 * 130.0);
		pos.x += wobble(x, t) * getPercent('drugged', params.player) * 112 * 0.8;
		return pos;
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		final x:Float = (params.distance * 0.025) + (params.lane * 0.3);
		final t:Float = 0.01 * (-params.songTime * 0.005 * 130.0);
		data.angleZ += wobble(x, t) * getPercent('drugged', params.player) * 20;
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
