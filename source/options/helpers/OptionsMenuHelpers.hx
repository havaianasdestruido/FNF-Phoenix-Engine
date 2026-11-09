package options.helpers;

import options.BaseOptionsMenu;
import options.Option;
import backend.ScreenLayout;
import flixel.FlxG;

import objects.Alphabet;
import objects.AttachedText;
import objects.CheckboxThingie;

// (duplicated in new() and regenList() -> now delegated here)
@:access(options.BaseOptionsMenu)
class OptionsMenuHelpers
{
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
