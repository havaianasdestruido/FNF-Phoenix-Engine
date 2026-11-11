package modchart.modifiers;

import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModchartVisuals;
import modchart.Modifier;

/** Centre/local zoom (`zoom`, `mini`, `localZoom`, `localMini`) — position + scale. */
class Zoom extends Modifier
{
	var curPercent:Null<Float> = -1;
	var localPercent:Null<Float> = -1;

	function updatePercent(params:ModchartParams):Void
	{
		curPercent = 1 + ((-getPercent('zoom', params.player) + getPercent('mini', params.player)) * 0.5);
		localPercent = 1 + ((-getPercent('localZoom', params.player) + getPercent('localMini', params.player)) * 0.5);
	}

	function applyZoom(pos:ModchartVec3, origin:ModchartVec3, amount:Float):ModchartVec3
	{
		final diff:ModchartVec3 = pos.subtract(origin);
		diff.x *= amount;
		diff.y *= amount;
		diff.z *= amount;
		return diff.add(origin);
	}

	override public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		updatePercent(params);
		if (curPercent != 1)
			pos = applyZoom(pos, new ModchartVec3(getScreenWidth() * 0.5, getScreenHeight() * 0.5), curPercent);
		if (localPercent != 1)
			pos = applyZoom(pos, new ModchartVec3(getReceptorX(Math.round(getKeyCount() * 0.5), params.player), getScreenHeight() * 0.5), localPercent);
		return pos;
	}

	override public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		if (curPercent == null)
			updatePercent(params);
		data.scaleX *= (curPercent * localPercent);
		data.scaleY *= (curPercent * localPercent);
		curPercent = null;
		localPercent = null;
		return data;
	}

	override public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}
}
