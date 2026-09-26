package play;

import backend.ClientPrefs;

import flixel.FlxBasic;
import flixel.addons.display.FlxPieDial;
import flixel.graphics.atlas.FlxAtlas;
import flixel.util.FlxSort;

typedef CutsceneEvent = {
	var time:Float;
	var func:Void->Void;
}

class CutsceneHandler extends FlxBasic
{
	public var timedEvents:Array<CutsceneEvent> = [];
	public var skipCallback:Void->Void = null;
	public var onStart:Void->Void = null;
	public var endTime:Float = 0;
	public var objects:Array<FlxSprite> = [];
	public var music:String = null;

	final _timeToSkip:Float = 1;
	var _canSkip:Bool = false;
	public var holdingTime:Float = 0;
	public var skipSprite:FlxPieDial;
	public var finishCallback:Void->Void = null;

	/**
	 * Executes the `new` operation.
	 * @param canSkip Input value for `canSkip`.
	 */
	public function new(canSkip:Bool = true)
	{
		super();

		timer(0, function()
		{
			if(music != null)
			{
				FlxG.sound.playMusic(Paths.music(music), 0, false);
				FlxG.sound.music.fadeIn();
			}
			if(onStart != null) onStart();
		});
		FlxG.state.add(this);

		this._canSkip = canSkip;
		if(canSkip)
		{
			skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
			skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
			skipSprite.x = FlxG.width - (skipSprite.width + 80);
			skipSprite.y = FlxG.height - (skipSprite.height + 72);
			skipSprite.amount = 0;
			skipSprite.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
			FlxG.state.add(skipSprite);
		}
	}

	private var cutsceneTime:Float = 0;
	private var firstFrame:Bool = false;
	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed)
	{
		super.update(elapsed);

		if(FlxG.state != PlayState.instance || !firstFrame)
		{
			firstFrame = true;
			return;
		}

		cutsceneTime += elapsed;
		while(timedEvents.length > 0 && timedEvents[0].time <= cutsceneTime)
		{
			timedEvents[0].func();
			timedEvents.shift();
		}

		if(_canSkip && cutsceneTime > 0.1)
		{
			if(FlxG.keys.anyPressed(ClientPrefs.keyBinds.get('accept')))
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			else if (holdingTime > 0)
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));

			updateSkipAlpha();
		}

		if(endTime <= cutsceneTime || holdingTime >= _timeToSkip)
		{
			if(holdingTime >= _timeToSkip)
			{
				trace('skipped cutscene');
				if(skipCallback != null)
					skipCallback();
			}
			else finishCallback();

			for (spr in objects)
			{
				spr.kill();
				PlayState.instance.remove(spr);
				spr.destroy();
			}

			skipSprite = FlxDestroyUtil.destroy(skipSprite);
			destroy();
			PlayState.instance.remove(this);
		}
	}

	/**
	 * Executes the `updateSkipAlpha` operation.
	 * @return Result produced by `updateSkipAlpha`, when applicable.
	 */
	function updateSkipAlpha()
	{
		if(skipSprite == null) return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	/**
	 * Executes the `push` operation.
	 * @param spr Input value for `spr`.
	 * @return Result produced by `push`, when applicable.
	 */
	public function push(spr:FlxSprite)
	{
		objects.push(spr);
	}

	/**
	 * Executes the `timer` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `timer`, when applicable.
	 */
	public function timer(time:Float, func:Void->Void)
	{
		timedEvents.push({time: time, func: func});
		timedEvents.sort(sortByTime);
	}

	/**
	 * Executes the `sortByTime` operation.
	 * @param Obj1 Input value for `Obj1`.
	 * @param Obj2 Input value for `Obj2`.
	 * @return Result produced by `sortByTime`, when applicable.
	 */
	function sortByTime(Obj1:CutsceneEvent, Obj2:CutsceneEvent):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.time, Obj2.time);
	}
}
