package objects;

import backend.Paths;


class TypedAlphabet extends Alphabet
{
	public var onFinish:Void->Void = null;
	public var finishedText:Bool = false;
	public var delay:Float = 0.05;
	public var sound:String = 'dialogue';
	public var volume:Float = 1;

	/**
	 * Executes the `new` operation.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @param text Input value for `text`.
	 * @param delay Input value for `delay`.
	 * @param bold Input value for `bold`.
	 */
	public function new(x:Float, y:Float, text:String = "", ?delay:Float = 0.05, ?bold:Bool = false)
	{
		super(x, y, text, bold);

		this.delay = delay;
	}

	/**
	 * Executes the `set_text` operation.
	 * @param newText Input value for `newText`.
	 * @return Result produced by `set_text`, when applicable.
	 */
	override private function set_text(newText:String)
	{
		super.set_text(newText);

		resetDialogue();
		return newText;
	}

	private var _curLetter:Int = -1;
	private var _timeToUpdate:Float = 0;
	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		if(!finishedText)
		{
			var playedSound:Bool = false;
			_timeToUpdate += elapsed;
			while(_timeToUpdate >= delay)
			{
				showCharacterUpTo(_curLetter + 1);
				if(!playedSound && sound != '' && (delay > 0.025 || _curLetter % 2 == 0))
				{
					FlxG.sound.play(Paths.sound(sound), volume);
				}
				playedSound = true;

				_curLetter++;
				if(_curLetter >= letters.length - 1)
				{
					finishedText = true;
					if(onFinish != null) onFinish();
					_timeToUpdate = 0;
					break;
				}
				_timeToUpdate = 0;
			}
		}

		super.update(elapsed);
	}

	/**
	 * Executes the `showCharacterUpTo` operation.
	 * @param upTo Input value for `upTo`.
	 * @return Result produced by `showCharacterUpTo`, when applicable.
	 */
	public function showCharacterUpTo(upTo:Int)
	{
		var start:Int = _curLetter;
		if(start < 0) start = 0;

		for (i in start...(upTo+1))
		{
			if(letters[i] != null) letters[i].visible = true;
			//trace('test, showing: $i');
		}
	}

	/**
	 * Executes the `resetDialogue` operation.
	 * @return Result produced by `resetDialogue`, when applicable.
	 */
	public function resetDialogue()
	{
		_curLetter = -1;
		finishedText = false;
		_timeToUpdate = 0;
		for (letter in letters)
		{
			letter.visible = false;
		}
	}

	/**
	 * Executes the `finishText` operation.
	 * @return Result produced by `finishText`, when applicable.
	 */
	public function finishText()
	{
		if(finishedText) return;

		showCharacterUpTo(letters.length - 1);
		if(sound != '') FlxG.sound.play(Paths.sound(sound), volume);
		finishedText = true;

		if(onFinish != null) onFinish();
		_timeToUpdate = 0;
	}
}
