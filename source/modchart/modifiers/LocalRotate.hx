package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.modifiers.Rotate;

/** `rotate` around the player's own receptor line (`localRotateX/Y/Z`). */
class LocalRotate extends Rotate
{
	override public function getOrigin(params:ModchartParams):ModchartVec3
	{
		final fixedLane:Int = Math.round(getKeyCount() * 0.5);
		return new ModchartVec3(getReceptorX(fixedLane, params.player), getReceptorY(fixedLane, params.player));
	}

	override public function getRotateName():String
	{
		return 'localRotate';
	}
}
