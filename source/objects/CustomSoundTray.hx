package objects;

import backend.Paths;
import flixel.system.frontEnds.SoundFrontEnd;
import flixel.system.ui.FlxSoundTray;
import flixel.util.FlxSave;
import flixel.FlxG;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.media.Sound;

class CustomSoundTray extends FlxSoundTray
{
	var graphicScale:Float = 0.3;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;
  var volumeMaxSound:String;
  
  public static var save:CustomSoundSave = null;

	public function new()
	{
		super();
		removeChildren();

		var bg:Bitmap = new Bitmap(Assets.getBitmapData('assets/soundtray/images/volumebox.png'));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		bg.smoothing = true;
		addChild(bg);

		var backingBar:Bitmap = new Bitmap(Assets.getBitmapData('assets/soundtray/images/bars_10.png'));
		backingBar.x = 9;
		backingBar.y = 5;
		backingBar.scaleX = graphicScale;
		backingBar.scaleY = graphicScale;
		backingBar.smoothing = true;
		addChild(backingBar);
		backingBar.alpha = 0.4;

		_bars = [];

		for (i in 1...11)
		{
			var bar:Bitmap = new Bitmap(Assets.getBitmapData('assets/soundtray/images/bars_$i.png'));
			bar.x = 9;
			bar.y = 5;
			bar.scaleX = graphicScale;
			bar.scaleY = graphicScale;
			bar.smoothing = true;
			addChild(bar);
			_bars.push(bar);
		}

		y = -height;
		screenCenter();

    // Resolve whichever audio container the build ships (ogg preferred), so
    // the tray keeps working on Flash/AIR builds that only decode MP3.
    volumeUpSound = Paths.resolveSoundAsset("sounds/soundtray/Volup", null, 'shared');
    volumeDownSound = Paths.resolveSoundAsset("sounds/soundtray/Voldown", null, 'shared');
    volumeMaxSound = Paths.resolveSoundAsset("sounds/soundtray/VolMAX", null, 'shared');

		// trace('Custom Sound Tray Added!');
	}

	function coolLerp(base:Float, target:Float, ratio:Float):Float
	{
		return base + (ratio * (FlxG.elapsed / (1 / 60))) * (target - base);
	}

	override function update(MS:Float):Void
	{
		y = coolLerp(y, lerpYPos, 0.1);
		alpha = coolLerp(alpha, alphaTarget, 0.1);

		var shouldHide = (FlxG.sound.muted == false && FlxG.sound.volume > 0);

		if (_timer > 0)
		{
			if (shouldHide)
				_timer -= (MS / 1000);
			alphaTarget = 1;
		}
		else if (y >= -height)
		{
			lerpYPos = -height - 10;
			alphaTarget = 0;
		}

		if (y <= -height)
		{
			visible = false;
			active = false;
		}
	}

	/**
	 * Makes the little volume tray slide out.
	 * @param up Whether the volume is increasing.
	 */
	override public function show(up:Bool = false):Void
	{
		_timer = 1;
		lerpYPos = 10;
		visible = true;
		active = true;
		var globalVolume:Int = Math.round(MathTools.logToLinear(FlxG.sound.volume) * 10);

		if (FlxG.sound.muted || FlxG.sound.volume == 0)
			globalVolume = 0;
		if (!silent)
		{
      var sound = up ? volumeUpSound : volumeDownSound;

      if (globalVolume == 10) sound = volumeMaxSound;

      if (sound != null) FlxG.sound.load(sound).play();
		}

		if (save == null) {
			save = new CustomSoundSave();
			save.load();
		}
		save.volume = FlxG.sound.volume;
		save.mute = FlxG.sound.muted;
		save.save();

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
				_bars[i].visible = true;
			else
				_bars[i].visible = false;
		}
	}
}

class CustomSoundFrontEnd extends SoundFrontEnd
{
	@:privateAccess
	override function changeVolume(Amount:Float):Void
	{
		muted = false;
		volume = MathTools.logToLinear(volume);
		volume += Amount;
		volume = MathTools.linearToLog(volume);
		showSoundTray(Amount > 0);
	}
}

// don't need the whole lib lol
private class MathTools {
	public static function linearToLog(x:Float, minValue:Float = 0.001):Float {
		x = Math.max(0, Math.min(1, x));
		return Math.exp(Math.log(minValue) * (1 - x));
	}

	public static function logToLinear(x:Float, minValue:Float = 0.001):Float {
		x = Math.max(minValue, Math.min(1, x));
		return 1 - (Math.log(x) / Math.log(minValue));
	}
}

class CustomSoundSave {
	public static var instance:CustomSoundSave = null;

	public var volume:Float = 1.0;
	public var mute:Bool = false;

	private var save:FlxSave = null;

	public function new() {
		save = new FlxSave();
		save.bind('sound_tray', CoolUtil.getSavePath());
		load();
	}

	public static function init() {
		if (instance == null) {
			instance = new CustomSoundSave();
		}
	}

	public function load():Void {
		if (save.data.volume != null) {
			volume = save.data.volume;
		}
		if (save.data.mute != null) {
			mute = save.data.mute;
		}
	}

	public function save():Void {
		save.data.volume = volume;
		save.data.mute = mute;
		save.flush();
	}

	public static function reset():Void {
		if (instance != null) {
			instance.volume = 1.0;
			instance.mute = false;
			instance.save();
		}
	}
}
