package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Triangle-wave lane drift (`zigZag`, plus YAFN `ZigZag.z`/`ZigZag.angle` as `zigZagZ`/`zigZagAngle`). */
class ZigZag extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final zigzag:Float = getPercent('zigZag', player);
		final yafnX:Float = getPercent('zigZagYafnX', player);
		final zigzagZ:Float = getPercent('zigZagZ', player) + getPercent('zigZagZ' + params.lane, player);
		if (zigzag == 0 && zigzagZ == 0 && yafnX == 0)
			return pos;
		final theta:Float = -params.distance / 112 * Math.PI;
		final outRelative:Float = Math.acos(cos(theta + Math.PI / 2)) / Math.PI * 2 - 1;
		pos.x += outRelative * 56 * zigzag;
		final wave:Float = sin((params.songTime - params.hitTime) / 50);
		pos.x += wave * yafnX;
		pos.z += wave * zigzagZ;
		return pos;
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		final player:Int = params.player;
		final angle:Float = getPercent('zigZagAngle', player) + getPercent('zigZagAngle' + params.lane, player);
		if (angle == 0)
			return data;
		data.angleZ += sin((params.songTime - params.hitTime) / 50) * angle;
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
