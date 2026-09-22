package objects;

import backend.Paths;
import backend.ClientPrefs;
import backend.CoolUtil;

import backend.WeekData;

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;

	/**
	 * Executes the `new` operation.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @param weekName Input value for `weekName`.
	 */
	public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y);
		loadGraphic(Paths.image('storymenu/' + weekName));
		//trace('Test added: ' + WeekData.getWeekNumber(weekNum) + ' (' + weekNum + ')');
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	private var isFlashing:Bool = false;

	/**
	 * Executes the `startFlashing` operation.
	 */
	public function startFlashing():Void
	{
		isFlashing = true;
	}

	var time:Float = 0;

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;
		y = FlxMath.lerp(y, (targetY * 120) + 480, CoolUtil.boundTo(elapsed * 10.2, 0, 1));

		if (isFlashing)
			color = (time % 0.1 > 0.05) ? FlxColor.WHITE : 0xFF33ffff;
	}
}
