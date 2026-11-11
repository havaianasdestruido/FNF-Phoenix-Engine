package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Spinning arrows (`confusion`, `confusionX/Y/Z`, `confusionOffset...`, plus `roll`/`twirl`/`dizzy` distance spin). */
class Confusion extends Modifier
{
	function applyConfusion(data:ModchartVisuals, params:ModchartParams, axis:String, realAxis:String):Void
	{
		final player:Int = params.player;
		var angle:Float = 0;
		angle -= (params.curBeat * (getPercent('confusion' + axis, player) + getPercent('confusion' + axis + params.lane, player))) % 360;
		angle += getPercent('confusionOffset' + axis, player) + getPercent('confusionOffset' + axis + params.lane, player);
		final dizzyName:String = switch (realAxis)
		{
			case 'x': 'roll';
			case 'y': 'twirl';
			default: 'dizzy';
		};
		angle += getPercent(dizzyName, player) * (params.distance * 0.1 * (1 + getPercent(dizzyName + 'Speed', player)));
		switch (realAxis)
		{
			case 'x': data.angleX += angle;
			case 'y': data.angleY += angle;
			default: data.angleZ += angle;
		}
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		applyConfusion(data, params, '', 'z');
		applyConfusion(data, params, 'x', 'x');
		applyConfusion(data, params, 'y', 'y');
		applyConfusion(data, params, 'z', 'z');
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
