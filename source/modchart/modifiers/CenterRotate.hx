package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.modifiers.Rotate;

/** `rotate` around the screen centre (`centerRotateX/Y/Z`). */
class CenterRotate extends Rotate
{
	override public function getOrigin(params:ModchartParams):ModchartVec3
	{
		return new ModchartVec3(getScreenWidth() * 0.5, getScreenHeight() * 0.5);
	}

	override public function getRotateName():String
	{
		return 'centerRotate';
	}
}
