package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Beat-synced bounce (`bounce`, `bounceX/Y/Z`, `bounceSpeed/Offset`). */
class Bounce extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final speed:Float = getPercent('bounceSpeed', player);
		final offset:Float = getPercent('bounceOffset', player);
		final bounce:Float = Math.abs(sin((params.curBeat + offset) * (1 + speed) * Math.PI)) * 112;
		pos.x += bounce * getPercent('bounceX', player);
		pos.y += bounce * getPercentLane('bounce', params.lane, player) + bounce * getPercent('bounceY', player);
		pos.z += bounce * getPercent('bounceZ', player);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
