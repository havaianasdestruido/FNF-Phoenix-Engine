package editors.charting;

// REFACTOR: extracted from editors.ChartingState (behavior-preserving)
import flixel.FlxSprite;
import flixel.text.FlxText;

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	/**
	 * Executes the `new` operation.
	 * @param X Input value for `X`.
	 * @param Y Input value for `Y`.
	 * @param FieldWidth Input value for `FieldWidth`.
	 * @param Text Input value for `Text`.
	 * @param Size Input value for `Size`.
	 * @param EmbeddedFont Input value for `EmbeddedFont`.
	 */
	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
	{
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
