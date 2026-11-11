package modchart;

/**
 * Per-arrow inputs every modifier reads. `distance` is the signed pixel
 * distance from the receptor along the scroll axis (positive = approaching),
 * `hitTime` is the note's strum time in ms, `songTime`/`curBeat` are the
 * song clock. `isReceptor` is true for strums (distance is always 0 there).
 */
class ModchartParams
{
	public var songTime:Float = 0;
	public var curBeat:Float = 0;
	public var hitTime:Float = 0;
	public var distance:Float = 0;
	public var lane:Int = 0;
	public var player:Int = 0;
	public var isTapArrow:Bool = false;
	public var isReceptor:Bool = false;
	/** Current receptor position (after strum transforms); defaults to the playfield layout when unset. */
	public var receptorX:Null<Float> = null;
	public var receptorY:Null<Float> = null;

	public function new()
	{
	}
}
