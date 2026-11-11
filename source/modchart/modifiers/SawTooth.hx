package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Sawtooth drift (`sawtooth`, `sawtoothPeriod`). */
class SawTooth extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final period:Float = 1 + getPercent('sawtoothPeriod', player);
		final scaled:Float = (0.5 / period * params.distance) / 112;
		pos.x += (getPercent('sawtooth', player) * 112) * (scaled - Math.floor(scaled));
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
