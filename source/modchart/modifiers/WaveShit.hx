package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.Modifier;

/**
 * YAFN `waveShit` port (`waveShit.y` / `waveShit.angle`).
 *
 * A song-time sine wave that sweeps across the global lane
 * (`lane + player * keyCount`, YAFN's `data`): `waveShit`/`waveShitY` bob
 * the scroll axis (`32 * cos(t - lane%2)`), `waveShitAngle` pushes the
 * depth axis (`64 * -sin(t - lane)`). `waveShitSpeed` (default 1) scales
 * the wave rate and `waveShitOffset` shifts its phase.
 */
class WaveShit extends Modifier
{
	public function new(pf)
	{
		super(pf);
		setPercent('waveShitSpeed', 1, -1);
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final player:Int = params.player;
		final yVal:Float = getPercentLane('waveShit', params.lane, player) + getPercent('waveShitY', player);
		final angleVal:Float = getPercent('waveShitAngle', player) + getPercent('waveShitAngle' + params.lane, player);
		if (yVal == 0 && angleVal == 0)
			return pos;
		final speed:Float = getPercent('waveShitSpeed', player);
		final offset:Float = getPercent('waveShitOffset', player);
		final globalLane:Int = params.lane + params.player * getKeyCount();
		final t:Float = params.songTime * 0.001 * Math.PI * speed + offset;
		if (yVal != 0)
			pos.y += 32 * yVal * cos(t - (globalLane % 2));
		if (angleVal != 0)
			pos.z += 64 * angleVal * -sin(t - globalLane);
		return pos;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
