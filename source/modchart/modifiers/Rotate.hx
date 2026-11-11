package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** 3D rotation of the arrow field around a lane-centre origin (`rotateX/Y/Z`). */
class Rotate extends Modifier
{
	public function getOrigin(params:ModchartParams):ModchartVec3
	{
		final fixedLane:Int = Math.round(getKeyCount() * 0.5);
		return new ModchartVec3(getReceptorX(fixedLane, params.player), getScreenHeight() / 2);
	}

	public function getRotateName():String
	{
		return 'rotate';
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final rotateName:String = getRotateName();
		final angleX:Float = getPercent(rotateName + 'X', params.player);
		final angleY:Float = getPercent(rotateName + 'Y', params.player);
		final angleZ:Float = getPercent(rotateName + 'Z', params.player);
		if (angleX == 0 && angleY == 0 && angleZ == 0)
			return pos;
		final origin:ModchartVec3 = getOrigin(params);
		var rotated:ModchartVec3 = ModchartVec3.rotate3D(pos.subtract(origin), angleX, angleY, angleZ);
		rotated = rotated.add(origin);
		return rotated;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
