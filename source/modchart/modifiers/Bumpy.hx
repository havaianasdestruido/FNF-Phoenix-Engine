package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Distance-based sine bumps on position and angle (`bumpy`, `bumpyX/Y/Z`, `bumpyAngle...`, `...Period/Offset/Mult`). */
class Bumpy extends Modifier
{
	public function new(pf)
	{
		super(pf);
		for (suffix in ['', 'Angle'])
		{
			setPercent('bumpy' + suffix + 'Mult', 1, -1);
			setPercent('bumpy' + suffix + 'XMult', 1, -1);
			setPercent('bumpy' + suffix + 'YMult', 1, -1);
			setPercent('bumpy' + suffix + 'ZMult', 1, -1);
		}
	}

	function bumpyShift(params:ModchartParams, axis:String):Float
	{
		final player:Int = params.player;
		final offset:Float = getPercent('bumpy' + axis + 'Offset', player) + getPercent('bumpy' + axis + params.lane + 'Offset', player);
		final period:Float = getPercent('bumpy' + axis + 'Period', player) + getPercent('bumpy' + axis + params.lane + 'Period', player);
		final mult:Float = getPercent('bumpy' + axis + 'Mult', player) + getPercent('bumpy' + axis + params.lane + 'Mult', player);
		final scrollSpeed:Float = getScrollSpeed();
		final phase:Float = ((params.distance * 0.01) + (100.0 * offset) / ((period * (mult * 24.0)) + 24.0)) / ((scrollSpeed * mult) / 2);
		final bumpyMath:Float = 40 * sin(phase) * (getKeyCount() / 2.0);
		return (getPercent('bumpy' + axis, player) + getPercent('bumpy' + axis + params.lane, player)) * bumpyMath;
	}

	function angleShift(params:ModchartParams, axis:String):Float
	{
		final player:Int = params.player;
		final offset:Float = getPercent('bumpyAngle' + axis + 'Offset', player) + getPercent('bumpyAngle' + axis + params.lane + 'Offset', player);
		final period:Float = getPercent('bumpyAngle' + axis + 'Period', player) + getPercent('bumpyAngle' + axis + params.lane + 'Period', player);
		final mult:Float = getPercent('bumpyAngle' + axis + 'Mult', player) + getPercent('bumpyAngle' + axis + params.lane + 'Mult', player);
		final scrollSpeed:Float = getScrollSpeed();
		final phase:Float = ((params.distance * 0.01) + (100.0 * offset) / ((period * (mult * 24.0)) + 24.0)) / ((scrollSpeed * mult) / 2);
		final bumpyMath:Float = 40 * sin(phase) * (getKeyCount() / 2.0);
		return (getPercent('bumpyAngle' + axis, player) + getPercent('bumpyAngle' + axis + params.lane, player)) * bumpyMath;
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		pos.z += bumpyShift(params, '');
		pos.x += bumpyShift(params, 'x');
		pos.y += bumpyShift(params, 'y');
		pos.z += bumpyShift(params, 'z');
		return pos;
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		data.angleZ += angleShift(params, '');
		data.angleX += angleShift(params, 'x');
		data.angleY += angleShift(params, 'y');
		data.angleZ += angleShift(params, 'z');
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
