package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/** Raw offsets (`x`/`y`/`z`, `xoffset`/`yoffset`/`zoffset`, plus lane variants and YAFN `noteOffset` velocity). */
class Transform extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		pos.x += getPercent('x', player) + getPercent('xoffset', player) + getPercent('x' + params.lane, player);
		pos.y += getPercent('y', player) + getPercent('yoffset', player) + getPercent('y' + params.lane, player);
		pos.z += getPercent('z', player) + getPercent('zoffset', player) + getPercent('z' + params.lane, player);
		// YAFN `noteOffset<lane>.x/y/z` is a velocity, not a constant: the
		// offset grows with (songTime - hitTime). Notes only — receptors sit
		// at hitTime == songTime, so this is a no-op for them anyway.
		if (!params.isReceptor)
		{
			final timeToHit:Float = params.hitTime - params.songTime;
			final velX:Float = getPercent('noteOffsetX', player) + getPercent('noteOffsetX' + params.lane, player);
			final velY:Float = getPercent('noteOffsetY', player) + getPercent('noteOffsetY' + params.lane, player);
			final velZ:Float = getPercent('noteOffsetZ', player) + getPercent('noteOffsetZ' + params.lane, player);
			pos.x += velX * (-timeToHit) / 100;
			pos.y += velY * (-timeToHit) / 100;
			pos.z += velZ * (-timeToHit) / 100;
		}
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
