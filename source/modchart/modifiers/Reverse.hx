package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/**
 * Scroll direction + speed. `reverse` mirrors the note's offset from its
 * receptor (so it composes with downscroll/middlescroll instead of fighting
 * `Note.followStrum`), `xmod` scales that offset, `scrollAngleX/Y/Z` tilt
 * the scroll vector, `split`/`alternate`/`cross` reverse subsets of lanes
 * and `centered` pulls the receptor line to screen centre.
 */
class Reverse extends Modifier
{
	public function new(pf)
	{
		super(pf);
		setPercent('xmod', 1, -1);
	}

	public function getReverseValue(lane:Int, player:Int):Float
	{
		final keyCount:Int = getKeyCount();
		var value:Float = 0;
		if (lane >= Math.floor(keyCount * 0.5))
			value += getPercent('split', player);
		if (lane % 2 == 1)
			value += getPercent('alternate', player);
		final first:Float = keyCount * 0.25;
		final last:Float = keyCount - 1 - first;
		if (lane >= first && lane <= last)
			value += getPercent('cross', player);
		value += getPercentLane('reverse', lane, player);
		if (getPercent('unboundedReverse', player) == 0)
		{
			value %= 2;
			if (value > 1)
				value = 2 - value;
		}
		return value;
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final reversePerc:Float = getReverseValue(params.lane, player);
		final centered:Float = getPercent('centered', player);

		// `pos` is absolute; reversing mirrors the offset from the receptor
		// (so it composes with downscroll/middlescroll instead of fighting
		// `Note.followStrum`). Receptors themselves only move when
		// `centered` pulls them.
		final baseX:Float = params.receptorX != null ? params.receptorX : getReceptorX(params.lane, player);
		final baseY:Float = params.receptorY != null ? params.receptorY : getReceptorY(params.lane, player);
		final receptorPos:ModchartVec3 = new ModchartVec3(baseX, baseY);
		var offset:ModchartVec3 = pos.subtract(receptorPos);
		offset.y = ModchartVec3.lerp(offset.y, -offset.y, reversePerc);
		offset.y *= getPercent('xmod', player) + getPercent('xmod' + params.lane, player);
		offset.x *= getPercent('xmod', player) + getPercent('xmod' + params.lane, player);

		final angleX:Float = getPercent('scrollAngleX', player);
		final angleY:Float = getPercent('scrollAngleY', player);
		final angleZ:Float = getPercent('scrollAngleZ', player);
		final shift:Float = params.distance * 0.25 * (1 + getPercent('curvedScrollPeriod', player));
		final curvedX:Float = angleX + shift * getPercent('curvedScrollX', player);
		final curvedY:Float = angleY + shift * getPercent('curvedScrollY', player);
		final curvedZ:Float = angleZ + shift * getPercent('curvedScrollZ', player);
		if (curvedX != 0 || curvedY != 0 || curvedZ != 0)
			offset = ModchartVec3.rotate3D(offset, curvedX, curvedY, curvedZ);

		var out:ModchartVec3 = receptorPos.add(offset);
		if (centered != 0)
		{
			final centre:ModchartVec3 = new ModchartVec3(getScreenWidth() * 0.5, getScreenHeight() * 0.5);
			out = out.lerpTo(centre.add(offset), centered);
		}
		// Receptors sit at distance 0: only `centered` moves them.
		if (params.isReceptor)
		{
			final base:ModchartVec3 = new ModchartVec3(getReceptorX(params.lane, player), getReceptorY(params.lane, player));
			if (centered != 0)
				return base.lerpTo(new ModchartVec3(getScreenWidth() * 0.5, getScreenHeight() * 0.5), centered);
			return base;
		}
		return out;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
