package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Scroll-axis shaping: `boost` accelerates, `brake` decelerates, `wave` ripples (`waveMult` default 1). */
class Boost extends Modifier
{
	public function new(pf)
	{
		super(pf);
		setPercent('waveMult', 1, -1);
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final lane:String = Std.string(params.lane);
		final yOffset:Float = params.distance;

		final boost:Float = getPercent('boost', player) + getPercent('boost' + lane, player);
		if (boost != 0)
		{
			final effectHeight:Float = getScreenHeight();
			final newYOffset:Float = yOffset * 1.5 / ((yOffset + effectHeight / 1.2) / effectHeight);
			var accel:Float = 0.75 * boost * (newYOffset - yOffset);
			accel = ModchartVec3.clamp(accel, -400, 400);
			pos.y += accel;
		}

		final brake:Float = getPercent('brake', player) + getPercent('brake' + lane, player);
		if (brake != 0)
		{
			final effectHeight:Float = getScreenHeight();
			final scale:Float = remap(yOffset, 0, effectHeight, 0, 1);
			final newYOffset:Float = yOffset * scale;
			var brakeAdjust:Float = 0.75 * brake * (newYOffset - yOffset);
			brakeAdjust = ModchartVec3.clamp(brakeAdjust, -400, 400);
			pos.y += brakeAdjust;
		}

		final wave:Float = getPercent('wave', player) + getPercent('wave' + lane, player);
		if (wave != 0)
			pos.y += wave * 20.0 * sin(yOffset / 96.0);

		return pos;
	}

	static function remap(value:Float, inMin:Float, inMax:Float, outMin:Float, outMax:Float):Float
	{
		if (inMax == inMin)
			return outMin;
		return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
