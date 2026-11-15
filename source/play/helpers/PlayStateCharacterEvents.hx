package play.helpers;

import backend.ClientPrefs;
import play.PlayState;

/** Character-change event handling, shared by normal and metadata-only play. */
@:access(play.PlayState)
class PlayStateCharacterEvents
{
	/** Match the runtime event convention: 0 = player, 1 = opponent, 2 = GF. */
	public static function characterType(value:String):Int
	{
		if (value == null) return 0;
		return switch (value.toLowerCase().trim())
		{
			case 'gf' | 'girlfriend': 2;
			case 'dad' | 'opponent': 1;
			default:
				final parsed:Null<Int> = Std.parseInt(value);
				parsed != null ? parsed : 0;
		};
	}

	// The live preference can change mid-song, but the groups' lifetime and
	// representation are fixed at creation. Do not touch retired groups or
	// suppress events for a song that still has full characters.
	static inline function enabled(state:PlayState):Bool
		return state.songCharacterVisuals || state.metadataOnlyCharacters;

	/** Events can come from both a separate events file and the chart. */
	public static function record(state:PlayState, time:Float, value1:String, value2:String):Void
	{
		var index:Int = state.charChangeTimes.length;
		while (index > 0 && state.charChangeTimes[index - 1] > time) index--;
		state.charChangeTimes.insert(index, time);
		state.charChangeNames.insert(index, value2);
		state.charChangeTypes.insert(index, characterType(value1));
	}

	public static function precache(state:PlayState, value1:String, value2:String):Void
	{
		if (enabled(state)) PlayStateCharacters.addCharacterToList(state, value2, characterType(value1));
	}

	public static function trigger(state:PlayState, value1:String, value2:String):Void
	{
		if (!enabled(state)) return;
		final charType:Int = characterType(value1);
		switch(charType) {
			case 0:
				if(state.boyfriend.curCharacter != value2) {
					if(!state.boyfriendMap.exists(value2)) {
						PlayStateCharacters.addCharacterToList(state, value2, charType);
					}

					var lastAlpha:Float = state.boyfriend.alpha;
					state.boyfriend.alpha = 0.00001;
					state.boyfriend = state.boyfriendMap.get(value2);
					state.boyfriend.alpha = lastAlpha;
					if (!value2.startsWith('bf') && !value2.startsWith('boyfriend')) state.iconP1.changeIcon(state.boyfriend.healthIcon);
					else {
						final iconToChange:String = switch (ClientPrefs.bfIconStyle){
							case 'VS Nonsense V2': 'bfnonsense';
							case 'Doki Doki+': 'bfdoki';
							case 'Leather Engine': 'bfleather';
							case "Mic'd Up": 'bfmup';
							case "FPS Plus": 'bffps';
							case "OS 'Engine'": 'bfos';
							default: state.boyfriend.healthIcon;
						}
						state.iconP1.changeIcon(iconToChange);
					}
					state.bfNoteskin = CharacterNoteSkin.resolve(state.boyfriend.noteskin, PlayState.isPixelStage);
				}
				state.setOnLuas('boyfriendName', state.boyfriend.curCharacter);

			case 1:
				if(state.dad.curCharacter != value2) {
					if(!state.dadMap.exists(value2)) {
						PlayStateCharacters.addCharacterToList(state, value2, charType);
					}

					var wasGf:Bool = state.dad.curCharacter.startsWith('gf');
					var lastAlpha:Float = state.dad.alpha;
					state.dad.alpha = 0.00001;
					state.dad = state.dadMap.get(value2);
					if(!state.dad.curCharacter.startsWith('gf')) {
						if(wasGf && state.gf != null) {
							state.gf.visible = true;
						}
					} else if(state.gf != null) {
						state.gf.visible = false;
					}
					state.dad.alpha = lastAlpha;
					state.iconP2.changeIcon(state.dad.healthIcon);
					if (ClientPrefs.botTxtStyle == 'VS Impostor') {
						if (state.botplayTxt != null) FlxTween.color(state.botplayTxt, 1, state.botplayTxt.color, FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]));

						if (state.scoreTxt != null && !ClientPrefs.hideHud) FlxTween.color(state.scoreTxt, 1, state.scoreTxt.color, FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]));
					}
					if (ClientPrefs.scoreStyle == 'JS Engine' && !ClientPrefs.hideHud)
						if (state.scoreTxt != null) FlxTween.color(state.scoreTxt, 1, state.scoreTxt.color, FlxColor.fromRGB(state.dad.healthColorArray[0], state.dad.healthColorArray[1], state.dad.healthColorArray[2]));

					state.dadNoteskin = CharacterNoteSkin.resolve(state.dad.noteskin, PlayState.isPixelStage);
				}
				state.setOnLuas('dadName', state.dad.curCharacter);

			case 2:
				if(state.gf != null)
				{
					if(state.gf.curCharacter != value2)
					{
						if(!state.gfMap.exists(value2))
						{
							PlayStateCharacters.addCharacterToList(state, value2, charType);
						}

						var lastAlpha:Float = state.gf.alpha;
						state.gf.alpha = 0.00001;
						state.gf = state.gfMap.get(value2);
						state.gf.alpha = lastAlpha;
					}
					state.setOnLuas('gfName', state.gf.curCharacter);
				}
		}
		PlayState.shouldDrainHealth = (state.opponentDrain || (PlayState.opponentChart ? state.boyfriend.healthDrain : state.dad.healthDrain));
		if (!state.opponentDrain && !Math.isNaN((PlayState.opponentChart ? state.boyfriend : state.dad).drainAmount)) state.healthDrainAmount = PlayState.opponentChart ? state.boyfriend.drainAmount : state.dad.drainAmount;
		if (!state.opponentDrain && !Math.isNaN((PlayState.opponentChart ? state.boyfriend : state.dad).drainFloor)) state.healthDrainFloor = PlayState.opponentChart ? state.boyfriend.drainFloor : state.dad.drainFloor;
		state.reloadHealthBarColors(state.dad.healthColorArray, state.boyfriend.healthColorArray);
		if (ClientPrefs.showNotes)
		{
			for (i in state.strumLineNotes.members)
			{
				if (i == null) continue;
				var noteskin:String = (i.player == 0 ? state.dadNoteskin : state.bfNoteskin);
				if (noteskin != null)
				{
					i.updateNoteSkin(noteskin);
					i.useRGBShader = noteskin.length < 1 && ClientPrefs.enableColorShader;
				}
			}
		}
		if (ClientPrefs.noteColorStyle == 'Char-Based')
		{
			for (group in [state.notes, state.sustainNotes])
				for (note in group){
					if (note == null || !note.alive)
						continue;
					if (ClientPrefs.enableColorShader) note.updateRGBColors();
				}
		}
	}
}
