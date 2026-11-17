package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/**
 * YAFN `IncomingAngle` port (`IncomingAngle.curve.x/y/z` + `IncomingAngle.smooth`).
 *
 * `incomingCurveX/Y/Z` bend the approach path with a distance sine
 * (`-sin((songTime - hitTime) / BPM) * curve`), while `incomingSmooth`
 * blends the scroll axis toward YAFN's quadratic ease: linear after the
 * hit, squared before it, mirrored for downscroll. Receptors are skipped
 * for `incomingSmooth` (YAFN only shapes notes).
 */
class IncomingAngle extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final lane:String = Std.string(params.lane);
		final curveX:Float = getPercent('incomingCurveX', player) + getPercent('incomingCurveX' + lane, player);
		final curveY:Float = getPercent('incomingCurveY', player) + getPercent('incomingCurveY' + lane, player);
		final curveZ:Float = getPercent('incomingCurveZ', player) + getPercent('incomingCurveZ' + lane, player);
		final smooth:Float = getPercent('incomingSmooth', player);
		if (curveX == 0 && curveY == 0 && curveZ == 0 && smooth == 0)
			return pos;

		// YAFN works in (songPosition - strumTime); Phoenix params carry the
		// same gap as (hitTime - songTime), so negate it once here.
		final diff:Float = params.songTime - params.hitTime;

		if (curveX != 0 || curveY != 0 || curveZ != 0)
		{
			final crochet:Float = getCrochet() == 0 ? 600 : getCrochet();
			final bpm:Float = 60000 / crochet;
			final curve:Float = sin(diff / bpm);
			pos.x -= curve * curveX;
			pos.y -= curve * curveY;
			pos.z -= curve * curveZ;
		}

		if (smooth != 0 && !params.isReceptor)
		{
			final receptorY:Float = params.receptorY != null ? params.receptorY : getReceptorY(params.lane, player);
			final speed:Float = getScrollSpeed() / 0.45;
			var targetY:Float;
			if (playfield.downscroll)
			{
				targetY = diff >= 0 ? receptorY + diff * 0.45 * speed : receptorY - 0.9 * diff * diff / 1000;
			}
			else
			{
				targetY = diff >= 0 ? receptorY - diff * 0.45 * speed : receptorY + 0.9 * diff * diff / 1000;
			}
			pos.y = ModchartVec3.lerp(pos.y, targetY, ModchartVec3.clamp(smooth, 0, 1));
		}

		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
