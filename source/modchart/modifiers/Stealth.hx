package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Alpha control (`stealth`/`dark`, `alpha`, `sudden`/`hidden` + `...Start/End/Glow`). */
class Stealth extends Modifier
{
	public function new(pf)
	{
		super(pf);
		setPercent('alpha', 1, -1);
		setPercent('suddenStart', 5, -1);
		setPercent('suddenEnd', 3, -1);
		setPercent('suddenGlow', 1, -1);
		setPercent('hiddenStart', 5, -1);
		setPercent('hiddenEnd', 3, -1);
		setPercent('hiddenGlow', 1, -1);
	}

	function computeSudden(data:ModchartVisuals, params:ModchartParams):Void
	{
		final player:Int = params.player;
		final sudden:Float = getPercent('sudden', player);
		if (sudden == 0)
			return;
		final start:Float = getPercent('suddenStart', player) * 100;
		final end:Float = getPercent('suddenEnd', player) * 100;
		final glow:Float = getPercent('suddenGlow', player);
		final alpha:Float = remap(ModchartVec3.clamp(params.distance, end, start), end, start, 1, 0);
		if (glow != 0)
			data.glow += Math.max(0, (1 - alpha) * sudden * 2) * glow;
		data.alpha *= alpha * sudden;
	}

	function computeHidden(data:ModchartVisuals, params:ModchartParams):Void
	{
		final player:Int = params.player;
		final hidden:Float = getPercent('hidden', player);
		if (hidden == 0)
			return;
		final start:Float = getPercent('hiddenStart', player) * 100;
		final end:Float = getPercent('hiddenEnd', player) * 100;
		final glow:Float = getPercent('hiddenGlow', player);
		final alpha:Float = remap(ModchartVec3.clamp(params.distance, end, start), end, start, 0, 1);
		if (glow != 0)
			data.glow += Math.max(0, (1 - alpha) * hidden * 2) * glow;
		data.alpha *= alpha * hidden;
	}

	static function remap(value:Float, inMin:Float, inMax:Float, outMin:Float, outMax:Float):Float
	{
		if (inMax == inMin)
			return outMin;
		return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		final player:Int = params.player;
		final visibilityName:String = params.isTapArrow ? 'stealth' : 'dark';
		final visibility:Float = getPercent(visibilityName, player) + getPercent(visibilityName + params.lane, player);
		data.alpha = ((getPercent('alpha', player) + getPercent('alpha' + params.lane, player)) * (1 - ((Math.max(0.5, visibility) - 0.5) * 2)));
		data.glow += visibility * 2;
		if (params.isTapArrow)
		{
			computeSudden(data, params);
			computeHidden(data, params);
		}
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
