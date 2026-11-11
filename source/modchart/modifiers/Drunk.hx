package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Sine wobble driven by song time + distance (`drunk`, `drunkX/Y/Z`, `drunkSpeed/Period/Offset`). */
class Drunk extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final xVal:Float = getPercentLane('drunk', params.lane, player) + getPercent('drunkX', player);
		final yVal:Float = getPercent('drunkY', player);
		final zVal:Float = getPercent('drunkZ', player);
		if (xVal == 0 && yVal == 0 && zVal == 0)
			return pos;
		final speed:Float = getPercent('drunkSpeed', player);
		final period:Float = getPercent('drunkPeriod', player);
		final offset:Float = getPercent('drunkOffset', player);
		final shift:Float = params.songTime * 0.001 * (1 + speed) + params.lane * ((offset * 0.2) + 0.2) + params.distance * ((period * 10) + 10) / getScreenHeight();
		final drunk:Float = cos(shift) * 56;
		pos.x += drunk * xVal;
		pos.y += drunk * yVal;
		pos.z += drunk * zVal;
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
