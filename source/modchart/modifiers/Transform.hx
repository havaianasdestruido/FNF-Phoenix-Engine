package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Raw offsets (`x`/`y`/`z`, `xoffset`/`yoffset`/`zoffset`, plus lane variants). */
class Transform extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		pos.x += getPercent('x', player) + getPercent('xoffset', player) + getPercent('x' + params.lane, player);
		pos.y += getPercent('y', player) + getPercent('yoffset', player) + getPercent('y' + params.lane, player);
		pos.z += getPercent('z', player) + getPercent('zoffset', player) + getPercent('z' + params.lane, player);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
