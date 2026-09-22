package psychlua;

import backend.Paths;

class DebugLuaText extends FlxText
{
	public var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>;
	/**
	 * Executes the `new` operation.
	 * @param text Input value for `text`.
	 * @param parentGroup Input value for `parentGroup`.
	 * @param color Input value for `color`.
	 */
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>, color:FlxColor) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("comic.ttf"), 16, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime < 0) disableTime = 0;
		if(disableTime < 1) alpha = disableTime;
		
		if(alpha == 0 || y >= FlxG.height) kill();
	}
}