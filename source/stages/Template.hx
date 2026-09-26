package stages;
import objects.Note;
import play.BaseStage;
import play.BaseStage.Countdown;
import play.PlayState;

import stages.objects.*;

class Template extends BaseStage
{
	// If you're moving your stage from PlayState to a stage file,
	// you might have to rename some variables if they're missing, for example: camZooming -> game.camZooming

	/**
	 * Executes the `create` operation.
	 * @return Result produced by `create`, when applicable.
	 */
	override function create()
	{
		// Spawn your stage sprites here.
		// Characters are not ready yet on this function, so you can't add things above them yet.
		// Use createPost() if that's what you want to do.
	}
	
	/**
	 * Executes the `createPost` operation.
	 * @return Result produced by `createPost`, when applicable.
	 */
	override function createPost()
	{
		// Use this function to layer things above characters!
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		// Code here
	}

	
	/**
	 * Executes the `countdownTick` operation.
	 * @param count Input value for `count`.
	 * @param num Input value for `num`.
	 * @return Result produced by `countdownTick`, when applicable.
	 */
	override function countdownTick(count:BaseStage.Countdown, num:Int)
	{
		switch(count)
		{
			case THREE: //num 0
			case TWO: //num 1
			case ONE: //num 2
			case GO: //num 3
			case START: //num 4
		}
	}

	// Steps, Beats and Sections:
	//    curStep, curDecStep
	//    curBeat, curDecBeat
	//    curSection
	/**
	 * Executes the `stepHit` operation.
	 * @return Result produced by `stepHit`, when applicable.
	 */
	override function stepHit()
	{
		// Code here
	}
	/**
	 * Executes the `beatHit` operation.
	 * @return Result produced by `beatHit`, when applicable.
	 */
	override function beatHit()
	{
		// Code here
	}
	/**
	 * Executes the `sectionHit` operation.
	 * @return Result produced by `sectionHit`, when applicable.
	 */
	override function sectionHit()
	{
		// Code here
	}

	// Substates for pausing/resuming tweens and timers
	/**
	 * Executes the `closeSubState` operation.
	 * @return Result produced by `closeSubState`, when applicable.
	 */
	override function closeSubState()
	{
		if(paused)
		{
			//timer.active = true;
			//tween.active = true;
		}
	}

	/**
	 * Executes the `openSubState` operation.
	 * @param SubState Input value for `SubState`.
	 * @return Result produced by `openSubState`, when applicable.
	 */
	override function openSubState(SubState:flixel.FlxSubState)
	{
		if(paused)
		{
			//timer.active = false;
			//tween.active = false;
		}
	}

	// For events
	/**
	 * Executes the `eventCalled` operation.
	 * @param eventName Input value for `eventName`.
	 * @param value1 Input value for `value1`.
	 * @param value2 Input value for `value2`.
	 * @param flValue1 Input value for `flValue1`.
	 * @param flValue2 Input value for `flValue2`.
	 * @param strumTime Input value for `strumTime`.
	 * @return Result produced by `eventCalled`, when applicable.
	 */
	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "My Event":
		}
	}
	/**
	 * Executes the `eventPushed` operation.
	 * @param event Input value for `event`.
	 * @return Result produced by `eventPushed`, when applicable.
	 */
	override function eventPushed(event:Note.EventNote)
	{
		// used for preloading assets used on events that doesn't need different assets based on its values
		switch(event.event)
		{
			case "My Event":
				//precacheImage('myImage') //preloads images/myImage.png
				//precacheSound('mySound') //preloads sounds/mySound.ogg
				//precacheMusic('myMusic') //preloads music/myMusic.ogg
		}
	}
	/**
	 * Executes the `eventPushedUnique` operation.
	 * @param event Input value for `event`.
	 * @return Result produced by `eventPushedUnique`, when applicable.
	 */
	override function eventPushedUnique(event:objects.Note.EventNote)
	{
		// used for preloading assets used on events where its values affect what assets should be preloaded
		switch(event.event)
		{
			case "My Event":
				switch(event.value1)
				{
					// If value 1 is "blah blah", it will preload these assets:
					case 'blah blah':
						//precacheImage('myImageOne') //preloads images/myImageOne.png
						//precacheSound('mySoundOne') //preloads sounds/mySoundOne.ogg
						//precacheMusic('myMusicOne') //preloads music/myMusicOne.ogg

					// If value 1 is "coolswag", it will preload these assets:
					case 'coolswag':
						//precacheImage('myImageTwo') //preloads images/myImageTwo.png
						//precacheSound('mySoundTwo') //preloads sounds/mySoundTwo.ogg
						//precacheMusic('myMusicTwo') //preloads music/myMusicTwo.ogg
					
					// If value 1 is not "blah blah" or "coolswag", it will preload these assets:
					default:
						//precacheImage('myImageThree') //preloads images/myImageThree.png
						//precacheSound('mySoundThree') //preloads sounds/mySoundThree.ogg
						//precacheMusic('myMusicThree') //preloads music/myMusicThree.ogg
				}
		}
	}
}