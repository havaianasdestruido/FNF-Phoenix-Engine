package modchart.modifiers;

import modchart.ModchartEase;
import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Circular lane motion (`radionic`) with a beat pulse on scale/glow. */
class Radionic extends Modifier
{
	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		final perc:Float = getPercent('radionic', params.player);
		if (perc == 0)
			return pos;
		final crochet:Float = getCrochet() == 0 ? 600 : getCrochet();
		final angle:Float = ((1 / crochet) * ((params.songTime + params.distance) * Math.PI * 0.25) + (Math.PI * params.player));
		final offsetX:Float = pos.x - getReceptorX(params.lane, params.player);
		final offsetY:Float = pos.y - getReceptorY(params.lane, params.player);
		final circf:Float = 112 + params.lane * 112;
		final sinAng:Float = sin(angle);
		final cosAng:Float = cos(angle);
		final targetX:Float = getScreenWidth() * 0.5 + ((sinAng * offsetY + cosAng * (circf + offsetX)) * 0.7) * 1.125;
		final targetY:Float = getScreenHeight() * 0.5 + ((cosAng * offsetY + sinAng * (circf + offsetX)) * 0.7) * 0.875;
		final target:ModchartVec3 = new ModchartVec3(targetX, targetY, pos.z);
		return pos.lerpTo(target, perc);
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		final perc:Float = getPercent('radionic', params.player);
		if (perc == 0)
			return data;
		final amount:Float = 0.6;
		final beatFrac:Float = params.curBeat - Math.floor(params.curBeat);
		data.scaleY = perc * (1 + amount - ModchartEase.cubeOut(beatFrac) * amount);
		data.scaleX = data.scaleY;
		data.glow = perc * (-(amount - ModchartEase.cubeOut(beatFrac) * amount) * 2);
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
