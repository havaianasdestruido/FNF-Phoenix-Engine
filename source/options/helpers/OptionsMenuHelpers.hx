package options.helpers;

import options.BaseOptionsMenu;
import options.Option;
import backend.ClientPrefs;
import backend.ScreenLayout;
import flixel.FlxG;

import objects.Alphabet;
import objects.AttachedText;
import objects.CheckboxThingie;

// (duplicated in new() and regenList() -> now delegated here)
@:access(options.BaseOptionsMenu)
class OptionsMenuHelpers
{
	/**
	 * Adds the **Master Volume** row (Options -> Audio, also in Misc).
	 *
	 * The row is a *mirror*: the real value is `FlxG.sound.volume`, which the
	 * volume keys, the sound tray and scripts all change. `ClientPrefs.masterVolume`
	 * only carries it (kept out of the save file and out of `.json` backups), and
	 * `backend.VolumeCurve` is the tray's own curve, so the row and the `+`/`-`
	 * keys agree about the same number.
	 *
	 * It is `Option.live`, so `readValue` re-reads the volume when the menu
	 * refreshes (`BaseOptionsMenu.refreshLiveOptions`) instead of freezing the
	 * number the list was built with.
	 */
	public static function addMasterVolumeRow(state:BaseOptionsMenu):Option
	{
		// Pick up the volume the game loaded (or that a key just changed).
		ClientPrefs.syncMasterVolume();

		var option:Option = new Option('Master Volume',
			'The loudness of everything the game plays: music, vocals, hitsounds\n'
			+ 'and the pause track. 0% is silent. The volume keys change the same\n'
			+ 'setting, and both stay in sync.',
			'masterVolume',
			'percent',
			1);
		option.live = true;
		option.readValue = ClientPrefs.readMasterVolume;
		option.onChange = () -> ClientPrefs.assignMasterVolume(ClientPrefs.masterVolume);

		// 2% a press on the full curve (a step of 0.02 on the 0..1 position), with
		// a gentle hold so a gamepad or a shaky touchscreen can still land on a
		// round number.
		option.changeValue = 0.02;
		option.scrollSpeed = 0.4;
		option.minValue = 0;
		option.maxValue = 1;
		// `decimals` is the precision of the *value* (0..1), not of the printed
		// percentage: 0 would round every step back to 0 or 1, so the row could
		// only ever be silent or full. Two decimals keep the 2% steps intact and
		// print whole percents ("57%", not "56.99999999999999%").
		option.decimals = 2;
		state.addOption(option);
		return option;
	}

	public static function createOptionRow(state:BaseOptionsMenu, optionsArray:Array<Option>)
	{
		// Options -> Visuals and UI -> UI Scale. Rows, spacing, checkboxes and
		// value labels all grow together so the list stays readable at 100/115/130%.
		final uiScale:Float = ScreenLayout.uiScale();
		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 290, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			/*optionText.forceX = 300;
			optionText.yMult = 90;*/
			optionText.targetY = i;
			optionText.setScale(uiScale);
			optionText.distancePerItem.set(20 * uiScale, 120 * uiScale);
			state.grpOptions.add(optionText);

			if(optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105 * uiScale, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				state.checkboxGroup.add(checkbox);
			} else if (optionsArray[i].type != 'link') {
				optionText.x -= 80 * uiScale;
				optionText.startPosition.x -= 80 * uiScale;
				//optionText.xAdd -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 80 * uiScale);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				valueText.setScale(uiScale);
				state.grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			//optionText.snapToPosition(); //Don't ignore me when i ask for not making a very pull request to uncomment this line ok

			if(optionsArray[i].showBoyfriend && state.boyfriend == null)
			{
				state.reloadBoyfriend();
			}
			state.updateTextFrom(optionsArray[i]);
		}
	}
}
