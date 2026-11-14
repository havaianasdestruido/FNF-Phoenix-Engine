package objects;

import flixel.FlxSprite;

/** Receptor stand-in: remembers the animation it was told to play. */
class StrumNote extends FlxSprite
{
	public var noteData:Int = 0;
	public var player:Int = 0;
	public var anim:String = null;

	public function new(x:Float, y:Float, leData:Int, player:Int, ?inEditor:Bool = false)
	{
		super(x, y);
		this.noteData = leData;
		this.player = player;
	}

	public function playAnim(anim:String, ?force:Bool = false):Void
	{
		this.anim = anim;
	}
}
