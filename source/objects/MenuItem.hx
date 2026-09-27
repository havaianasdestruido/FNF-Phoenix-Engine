package objects;

import backend.Paths;
import backend.ClientPrefs;
import backend.CoolUtil;

import backend.WeekData;

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;

	public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y);
		var weekGraphic = Paths.image('storymenu/' + weekName);
		if (weekGraphic == null) {
			// No week title card (e.g. content-stripped builds ship no
			// storymenu/ art): solid bar so the row stays visible/selectable.
			// The week name itself is shown by txtWeekTitle.
			makeGraphic(800, 100, 0xFF222222, true);
		} else {
			loadGraphic(weekGraphic);
		}
		//trace('Test added: ' + WeekData.getWeekNumber(weekNum) + ' (' + weekNum + ')');
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	private var isFlashing:Bool = false;

	public function startFlashing():Void
	{
		isFlashing = true;
	}

	var time:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;
		y = FlxMath.lerp(y, (targetY * 120) + 480, CoolUtil.boundTo(elapsed * 10.2, 0, 1));

		if (isFlashing)
			color = (time % 0.1 > 0.05) ? FlxColor.WHITE : 0xFF33ffff;
	}
}
