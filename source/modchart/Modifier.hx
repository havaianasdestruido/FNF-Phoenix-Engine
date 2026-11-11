package modchart;

/**
 * Base class for every modchart modifier. A modifier transforms an arrow's
 * 3D position (`render`) and/or its visual parameters (`visuals`); the
 * playfield runs the active chain in insertion order.
 *
 * Percent lookup follows FunkinModchart: `getPercent('drunk', player)` reads
 * the base percent, and helpers like `getPercentLane('drunk', lane, player)`
 * sum the base plus the lane-suffixed variant (`drunk0`..`drunk3`).
 */
class Modifier
{
	public var playfield:PlayField;

	public function new(playfield:PlayField)
	{
		this.playfield = playfield;
	}

	public function render(pos:ModchartVec3, params:ModchartParams):ModchartVec3
	{
		return pos;
	}

	public function visuals(data:ModchartVisuals, params:ModchartParams):ModchartVisuals
	{
		return data;
	}

	public function shouldRun(params:ModchartParams):Bool
	{
		return true;
	}

	public inline function getPercent(name:String, player:Int):Float
	{
		return playfield.getPercent(name, player);
	}

	public inline function getPercentLane(name:String, lane:Int, player:Int):Float
	{
		return getPercent(name, player) + getPercent(name + lane, player);
	}

	public inline function setPercent(name:String, value:Float, player:Int = -1):Void
	{
		playfield.setPercent(name, value, player);
	}

	public inline function getScrollSpeed():Float
	{
		return playfield.scrollSpeed;
	}

	public inline function getCrochet():Float
	{
		return playfield.crochet;
	}

	public inline function getKeyCount():Int
	{
		return playfield.keyCount;
	}

	public inline function getScreenWidth():Float
	{
		return playfield.screenWidth;
	}

	public inline function getScreenHeight():Float
	{
		return playfield.screenHeight;
	}

	public inline function getReceptorX(lane:Int, player:Int):Float
	{
		return playfield.getReceptorX(lane, player);
	}

	public inline function getReceptorY(lane:Int, player:Int):Float
	{
		return playfield.getReceptorY(lane, player);
	}

	public inline function sin(value:Float):Float
	{
		return Math.sin(value);
	}

	public inline function cos(value:Float):Float
	{
		return Math.cos(value);
	}
}
