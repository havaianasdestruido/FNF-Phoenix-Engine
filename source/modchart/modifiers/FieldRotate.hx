package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.modifiers.Rotate;

/** `rotate` around the playfield centre (`fieldRotateX/Y/Z`). */
class FieldRotate extends Rotate
{
	override public function getOrigin(params:ModchartParams):ModchartVec3
	{
		var x:Float = (getScreenWidth() * 0.5) - 112 - 54 + 112 * 1.5;
		switch (params.player)
		{
			case 0: x -= getScreenWidth() * 0.5 - 112 * 2 - 100;
			case 1: x += getScreenWidth() * 0.5 - 112 * 2 - 100;
		}
		x -= 56;
		return new ModchartVec3(x, getScreenHeight() * 0.5);
	}

	override public function getRotateName():String
	{
		return 'fieldRotate';
	}
}
