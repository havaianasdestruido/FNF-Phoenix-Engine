package editors;
import backend.Paths;
//We gotta have music in the Editors!


class EditingMusic extends flixel.FlxBasic
{
	public var music:FlxSound = new FlxSound();
	public var startTimer:FlxTimer = null;

	public var musicPaused:Bool = false;

	/**
	 * Executes the `new` operation.
*/
	public function new() {
		super();
		playMusic(1);
	}

		/**
		 * Executes the `shuffle` operation.
		 * @return Result produced by `shuffle`, when applicable.
		 */
		public function shuffle() {
			music.time = 0;
			music.loadEmbedded(Paths.music('editorMusic/' + Std.string(FlxG.random.int(0, 4))));
			music.fadeIn(1, 0, 0.5);
			music.onComplete = shuffle;
		}

		/**
		 * Executes the `pauseMusic` operation.
		 * @return Result produced by `pauseMusic`, when applicable.
		 */
		public function pauseMusic() {
			music.pause();
			musicPaused = true;
			if (startTimer != null) startTimer.cancel();
			startTimer = null;
		}
		/**
		 * Executes the `unpauseMusic` operation.
		 * @param time Input value for `time`.
		 * @return Result produced by `unpauseMusic`, when applicable.
		 */
		public function unpauseMusic(time:Float = 0) {
			musicPaused = false;
			if (time > 0)
		{
			if (music.fadeTween != null)
				music.fadeTween.cancel(); //cancel the fade tween so it doesnt NULL OBJECT REFERENCE
			if (startTimer != null) startTimer.cancel();
			startTimer = new FlxTimer().start(time, function(tmr:FlxTimer)
				{
					music.fadeIn(1, 0, 0.5);
				});
		}
			else music.play();
		}
		/**
		 * Executes the `FocusLost` operation.
		 * @return Result produced by `FocusLost`, when applicable.
		 */
		public function FocusLost()
		{
			pauseMusic();
		}
		/**
		 * Executes the `FocusGained` operation.
		 */
		public function FocusGained():Void
		{
			unpauseMusic();
		}
		/**
		 * Executes the `destroy` operation.
		 * @return Result produced by `destroy`, when applicable.
		 */
		override public function destroy()
		{
			if (music.fadeTween != null)
				music.fadeTween.cancel(); //cancel the fade tween so it doesnt NULL OBJECT REFERENCE
			if (startTimer != null) startTimer.cancel();
		   	if (music != null) music.destroy();
			reset();
		}
		/**
		 * Executes the `playMusic` operation.
		 * @param time Input value for `time`.
		 * @return Result produced by `playMusic`, when applicable.
		 */
		public function playMusic(time:Float = 0)
		{
			if (time > 0)
		{
				startTimer = new FlxTimer().start(time, function(tmr:FlxTimer)
					{
						shuffle();
					});
		}
			else shuffle();
		}

	/**
	 * Executes the `reset` operation.
	 * @return Result produced by `reset`, when applicable.
	 */
	public function reset() {
		music.onComplete = null;
	}
	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		music.update(elapsed);
	}
}

