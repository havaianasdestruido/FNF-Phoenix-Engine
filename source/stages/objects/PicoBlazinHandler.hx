package stages.objects;
import play.PlayState;

import objects.Note;
import objects.Character;

// Pico Note functions
class PicoBlazinHandler
{
	/**
	 * Executes the `new` operation.
*/
	public function new() {}

	var cantUppercut = false;
	/**
	 * Executes the `noteHit` operation.
	 * @param note Input value for `note`.
	 * @return Result produced by `noteHit`, when applicable.
	 */
	public function noteHit(note:Note)
	{
		if (wasNoteHitPoorly(note.rating) && isPlayerLowHealth() && isDarnellPreppingUppercut())
		{
			playPunchHighAnim();
			return;
		}

		if (cantUppercut)
		{
			playBlockAnim();
			cantUppercut = false;
			return;
		}

		switch(note.noteType)
		{
			case "weekend-1-punchlow":
				playPunchLowAnim();
			case "weekend-1-punchlowblocked":
				playPunchLowAnim();
			case "weekend-1-punchlowdodged":
				playPunchLowAnim();
			case "weekend-1-punchlowspin":
				playPunchLowAnim();

			case "weekend-1-punchhigh":
				playPunchHighAnim();
			case "weekend-1-punchhighblocked":
				playPunchHighAnim();
			case "weekend-1-punchhighdodged":
				playPunchHighAnim();
			case "weekend-1-punchhighspin":
				playPunchHighAnim();

			case "weekend-1-blockhigh":
				playBlockAnim();
			case "weekend-1-blocklow":
				playBlockAnim();
			case "weekend-1-blockspin":
				playBlockAnim();

			case "weekend-1-dodgehigh":
				playDodgeAnim();
			case "weekend-1-dodgelow":
				playDodgeAnim();
			case "weekend-1-dodgespin":
				playDodgeAnim();

			// Pico ALWAYS gets punched.
			case "weekend-1-hithigh":
				playHitHighAnim();
			case "weekend-1-hitlow":
				playHitLowAnim();
			case "weekend-1-hitspin":
				playHitSpinAnim();

			case "weekend-1-picouppercutprep":
				playUppercutPrepAnim();
			case "weekend-1-picouppercut":
				playUppercutAnim(true);

			case "weekend-1-darnelluppercutprep":
				playIdleAnim();
			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();
			case "weekend-1-fakeout":
				playFakeoutAnim();
			case "weekend-1-taunt":
				playTauntConditionalAnim();
			case "weekend-1-tauntforce":
				playTauntAnim();
			case "weekend-1-reversefakeout":
				playIdleAnim(); // TODO: Which anim?
		}
	}

	/**
	 * Executes the `noteMiss` operation.
	 * @param note Input value for `note`.
	 * @return Result produced by `noteMiss`, when applicable.
	 */
	public function noteMiss(note:Note)
	{
		//trace('missed note!');
		if (isDarnellInUppercut())
		{
			playUppercutHitAnim();
			return;
		}

		if (willMissBeLethal())
		{
			playHitLowAnim();
			return;
		}

		if (cantUppercut)
		{
			playHitHighAnim();
			return;
		}

		switch (note.noteType)
		{
			// Pico fails to punch, and instead gets hit!
			case "weekend-1-punchlow":
				playHitLowAnim();
			case "weekend-1-punchlowblocked":
				playHitLowAnim();
			case "weekend-1-punchlowdodged":
				playHitLowAnim();
			case "weekend-1-punchlowspin":
				playHitSpinAnim();

			// Pico fails to punch, and instead gets hit!
			case "weekend-1-punchhigh":
				playHitHighAnim();
			case "weekend-1-punchhighblocked":
				playHitHighAnim();
			case "weekend-1-punchhighdodged":
				playHitHighAnim();
			case "weekend-1-punchhighspin":
				playHitSpinAnim();

			// Pico fails to block, and instead gets hit!
			case "weekend-1-blockhigh":
				playHitHighAnim();
			case "weekend-1-blocklow":
				playHitLowAnim();
			case "weekend-1-blockspin":
				playHitSpinAnim();

			// Pico fails to dodge, and instead gets hit!
			case "weekend-1-dodgehigh":
				playHitHighAnim();
			case "weekend-1-dodgelow":
				playHitLowAnim();
			case "weekend-1-dodgespin":
				playHitSpinAnim();

			// Pico ALWAYS gets punched.
			case "weekend-1-hithigh":
				playHitHighAnim();
			case "weekend-1-hitlow":
				playHitLowAnim();
			case "weekend-1-hitspin":
				playHitSpinAnim();

			// Fail to dodge the uppercut.
			case "weekend-1-picouppercutprep":
				playPunchHighAnim();
				cantUppercut = true;
			case "weekend-1-picouppercut":
				playUppercutAnim(false);

			// Darnell's attempt to uppercut, Pico dodges or gets hit.
			case "weekend-1-darnelluppercutprep":
				playIdleAnim();
			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();
			case "weekend-1-fakeout":
				playHitHighAnim();
			case "weekend-1-taunt":
				playTauntConditionalAnim();
			case "weekend-1-tauntforce":
				playTauntAnim();
			case "weekend-1-reversefakeout":
				playIdleAnim();
		}
	}
	
	/**
	 * Executes the `noteMissPress` operation.
	 * @param direction Input value for `direction`.
	 * @return Result produced by `noteMissPress`, when applicable.
	 */
	public function noteMissPress(direction:Int)
	{
		if (willMissBeLethal())
			playHitLowAnim(); // Darnell throws a punch so that Pico dies.
		else 
			playPunchHighAnim(); // Pico wildly throws punches but Darnell dodges.
	}

	/**
	 * Executes the `movePicoToBack` operation.
	 * @return Result produced by `movePicoToBack`, when applicable.
	 */
	function movePicoToBack()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos < dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	/**
	 * Executes the `movePicoToFront` operation.
	 * @return Result produced by `movePicoToFront`, when applicable.
	 */
	function movePicoToFront()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos > dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	var alternate:Bool = false;
	/**
	 * Executes the `doAlternate` operation.
	 * @return Result produced by `doAlternate`, when applicable.
	 */
	function doAlternate():String
	{
		alternate = !alternate;
		return alternate ? '1' : '2';
	}

	/**
	 * Executes the `playBlockAnim` operation.
	 * @return Result produced by `playBlockAnim`, when applicable.
	 */
	function playBlockAnim()
	{
		boyfriend.playAnim('block', true);
		FlxG.camera.shake(0.002, 0.1);
		moveToBack();
	}

	/**
	 * Executes the `playCringeAnim` operation.
	 * @return Result produced by `playCringeAnim`, when applicable.
	 */
	function playCringeAnim()
	{
		boyfriend.playAnim('cringe', true);
		moveToBack();
	}

	/**
	 * Executes the `playDodgeAnim` operation.
	 * @return Result produced by `playDodgeAnim`, when applicable.
	 */
	function playDodgeAnim()
	{
		boyfriend.playAnim('dodge', true);
		moveToBack();
	}

	/**
	 * Executes the `playIdleAnim` operation.
	 * @return Result produced by `playIdleAnim`, when applicable.
	 */
	function playIdleAnim()
	{
		boyfriend.playAnim('idle', false);
		moveToBack();
	}

	/**
	 * Executes the `playFakeoutAnim` operation.
	 * @return Result produced by `playFakeoutAnim`, when applicable.
	 */
	function playFakeoutAnim()
	{
		boyfriend.playAnim('fakeout', true);
		moveToBack();
	}

	/**
	 * Executes the `playUppercutPrepAnim` operation.
	 * @return Result produced by `playUppercutPrepAnim`, when applicable.
	 */
	function playUppercutPrepAnim()
	{
		boyfriend.playAnim('uppercutPrep', true);
		moveToFront();
	}

	/**
	 * Executes the `playUppercutAnim` operation.
	 * @param hit Input value for `hit`.
	 * @return Result produced by `playUppercutAnim`, when applicable.
	 */
	function playUppercutAnim(hit:Bool)
	{
		boyfriend.playAnim('uppercut', true);
		if (hit) FlxG.camera.shake(0.005, 0.25);
		moveToFront();
	}

	/**
	 * Executes the `playUppercutHitAnim` operation.
	 * @return Result produced by `playUppercutHitAnim`, when applicable.
	 */
	function playUppercutHitAnim()
	{
		boyfriend.playAnim('uppercutHit', true);
		FlxG.camera.shake(0.005, 0.25);
		moveToBack();
	}

	/**
	 * Executes the `playHitHighAnim` operation.
	 * @return Result produced by `playHitHighAnim`, when applicable.
	 */
	function playHitHighAnim()
	{
		boyfriend.playAnim('hitHigh', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	/**
	 * Executes the `playHitLowAnim` operation.
	 * @return Result produced by `playHitLowAnim`, when applicable.
	 */
	function playHitLowAnim()
	{
		boyfriend.playAnim('hitLow', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	/**
	 * Executes the `playHitSpinAnim` operation.
	 * @return Result produced by `playHitSpinAnim`, when applicable.
	 */
	function playHitSpinAnim()
	{
		boyfriend.playAnim('hitSpin', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	/**
	 * Executes the `playPunchHighAnim` operation.
	 * @return Result produced by `playPunchHighAnim`, when applicable.
	 */
	function playPunchHighAnim()
	{
		boyfriend.playAnim('punchHigh' + doAlternate(), true);
		moveToFront();
	}

	/**
	 * Executes the `playPunchLowAnim` operation.
	 * @return Result produced by `playPunchLowAnim`, when applicable.
	 */
	function playPunchLowAnim()
	{
		boyfriend.playAnim('punchLow' + doAlternate(), true);
		moveToFront();
	}

	/**
	 * Executes the `playTauntConditionalAnim` operation.
	 * @return Result produced by `playTauntConditionalAnim`, when applicable.
	 */
	function playTauntConditionalAnim()
	{
		if (boyfriend.getAnimationName() == "fakeout")
			playTauntAnim();
		else
			playIdleAnim();
	}

	/**
	 * Executes the `playTauntAnim` operation.
	 * @return Result produced by `playTauntAnim`, when applicable.
	 */
	function playTauntAnim()
	{
		boyfriend.playAnim('taunt', true);
		moveToBack();
	}

	/**
	 * Executes the `willMissBeLethal` operation.
	 * @return Result produced by `willMissBeLethal`, when applicable.
	 */
	function willMissBeLethal()
	{
		return PlayState.instance.health <= 0.0 && !PlayState.instance.practiceMode;
	}
	
	/**
	 * Executes the `isDarnellPreppingUppercut` operation.
	 * @return Result produced by `isDarnellPreppingUppercut`, when applicable.
	 */
	function isDarnellPreppingUppercut()
	{
		return dad.getAnimationName() == 'uppercutPrep';
	}

	/**
	 * Executes the `isDarnellInUppercut` operation.
	 * @return Result produced by `isDarnellInUppercut`, when applicable.
	 */
	function isDarnellInUppercut()
	{
		return dad.getAnimationName() == 'uppercut' || dad.getAnimationName() == 'uppercut-hold';
	}

	/**
	 * Executes the `wasNoteHitPoorly` operation.
	 * @param rating Input value for `rating`.
	 * @return Result produced by `wasNoteHitPoorly`, when applicable.
	 */
	function wasNoteHitPoorly(rating:String)
	{
		return (rating == "bad" || rating == "shit");
	}

	/**
	 * Executes the `isPlayerLowHealth` operation.
	 * @return Result produced by `isPlayerLowHealth`, when applicable.
	 */
	function isPlayerLowHealth()
	{
		return PlayState.instance.health <= 0.3 * 2;
	}
	
	/**
	 * Executes the `moveToBack` operation.
	 * @return Result produced by `moveToBack`, when applicable.
	 */
	function moveToBack()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos < dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	/**
	 * Executes the `moveToFront` operation.
	 * @return Result produced by `moveToFront`, when applicable.
	 */
	function moveToFront()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos > dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	var boyfriend(get, never):Character;
	var dad(get, never):Character;
	var boyfriendGroup(get, never):FlxSpriteGroup;
	var dadGroup(get, never):FlxSpriteGroup;
	/**
	 * Executes the `get_boyfriend` operation.
	 * @return Result produced by `get_boyfriend`, when applicable.
	 */
	function get_boyfriend() return PlayState.instance.boyfriend;
	/**
	 * Executes the `get_dad` operation.
	 * @return Result produced by `get_dad`, when applicable.
	 */
	function get_dad() return PlayState.instance.dad;
	/**
	 * Executes the `get_boyfriendGroup` operation.
	 * @return Result produced by `get_boyfriendGroup`, when applicable.
	 */
	function get_boyfriendGroup() return PlayState.instance.boyfriendGroup;
	/**
	 * Executes the `get_dadGroup` operation.
	 * @return Result produced by `get_dadGroup`, when applicable.
	 */
	function get_dadGroup() return PlayState.instance.dadGroup;
}