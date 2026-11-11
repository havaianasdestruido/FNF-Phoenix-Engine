package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Arrow scale (`scale`, `scaleX/Y`, `tiny`, `tinyX/Y`). */
class Scale extends Modifier
{
	public function new(pf)
	{
		super(pf);
		setPercent('scale', 1, -1);
		setPercent('scaleX', 1, -1);
		setPercent('scaleY', 1, -1);
	}

	function applyScale(data:ModchartVisuals, params:ModchartParams, axis:String, realAxis:String):Void
	{
		final player:Int = params.player;
		var scale:Float = 1;
		scale *= getPercent('scale' + axis, player) + getPercent('scale' + axis + params.lane, player);
		scale *= 1 - (getPercent('tiny' + axis, player) + getPercent('tiny' + axis + params.lane, player)) * 0.5;
		switch (realAxis)
		{
			case 'x': data.scaleX *= scale;
			case 'y': data.scaleY *= scale;
			default:
				data.scaleX *= scale;
				data.scaleY *= scale;
		}
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		applyScale(data, params, '', '');
		applyScale(data, params, 'x', 'x');
		applyScale(data, params, 'y', 'y');
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
