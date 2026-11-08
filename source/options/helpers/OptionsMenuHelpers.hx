package options.helpers;

import backend.MenuLayout;
import backend.ScreenLayout;
import flixel.FlxG;

import options.BaseOptionsMenu;
import options.Option;
import objects.Alphabet;
import objects.AttachedText;
import objects.CheckboxThingie;

/**
 * Builds and lays out the option rows of a `BaseOptionsMenu`.
 *
 * The row building used to be duplicated in `new()` and `regenList()`; both now
 * call `createOptionRow`. The layout is a centered three-column block
 * (`checkbox | label | value`) whose geometry comes from `backend.MenuLayout`.
 *
 * @see backend.MenuLayout for the block math, kept Flixel-free so it can be
 *      covered by `tests/haxe/MenuLayoutSpec.hx`.
 */
@:access(options.BaseOptionsMenu)
class OptionsMenuHelpers
{
	/**
	 * Builds one row per option: the label, plus its value text or checkbox.
	 *
	 * Rows used to be built at a fixed left offset, so the list hugged the left
	 * edge of the window. They are now laid out by `centerRows`, which centers
	 * the list as one block: `checkbox + label + value`.
	 */
	public static function createOptionRow(state:BaseOptionsMenu, optionsArray:Array<Option>)
	{
		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(0, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			// No horizontal shear: the list is a centered column, so a row that
			// is not selected must not drift sideways as the player scrolls.
			optionText.changeX = false;
			optionText.targetY = i;
			state.grpOptions.add(optionText);

			if(optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(0, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				state.checkboxGroup.add(checkbox);
			} else if(optionsArray[i].type != 'link') {
				// The value hangs off the label through `sprTracker`; the gap
				// between them lives in `offsetX`, set by `centerRows`.
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue());
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				state.grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}

			if(optionsArray[i].showBoyfriend && state.boyfriend == null)
			{
				state.reloadBoyfriend();
			}
			state.updateTextFrom(optionsArray[i]);
		}

		centerRows(state);
	}

	/**
	 * Centers the option list on the screen as one aligned column.
	 *
	 * The list is measured as a block of three columns - checkbox, label and
	 * value - and that block is centered on the window with
	 * `backend.MenuLayout`. Inside it the columns line up between rows, so the
	 * list reads as a table instead of the ragged left-aligned stack it used to
	 * be:
	 *
	 * - every checkbox starts on the checkbox column, one gap before the labels;
	 * - every label starts on the label column;
	 * - every value starts on the value column, right of the widest label, so the
	 *   values line up even when the labels differ in length.
	 *
	 * Rows without a checkbox or a value (a `link` action such as
	 * "Export Settings") keep the same label origin as the others, so the column
	 * does not wobble when the player scrolls.
	 *
	 * The value column is sized from every value the option can show, not just
	 * the one on screen, so scrolling a value does not shift the whole list.
	 *
	 * Safe to call at any time: after `createOptionRow`, after a resize (the
	 * centered position depends on the window width), after a list regen and
	 * after an imported setting changed a label.
	 */
	public static function centerRows(state:BaseOptionsMenu)
	{
		final labels:Array<Alphabet> = state.grpOptions.members;
		final options:Array<Option> = state.optionsArray;
		if (labels == null || options == null || labels.length == 0) return;

		// Rows are built 1:1 with `optionsArray`, so a row index is also the ID
		// used by `checkboxGroup` and `grpTexts`.
		var widestLabel:Float = 0;
		var checkboxColumn:Float = 0;
		var anyCheckbox:Bool = false;
		for (i in 0...labels.length)
		{
			final label:Alphabet = labels[i];
			if (label == null) continue;
			widestLabel = Math.max(widestLabel, label.width);
			final option:Option = (i < options.length) ? options[i] : null;
			if (option != null && option.type == 'bool')
			{
				anyCheckbox = true;
				checkboxColumn = Math.max(checkboxColumn, checkboxWidth(state, i));
			}
		}

		final valueColumnWidth:Float = measureValueColumn(options);
		final blockWidth:Float = MenuLayout.blockWidth(widestLabel, valueColumnWidth, checkboxColumn, anyCheckbox);
		final blockLeft:Float = MenuLayout.centeredStart(blockWidth, FlxG.width, ScreenLayout.contentLeft(FlxG.width));

		final labelLeft:Float = MenuLayout.labelColumn(blockLeft, checkboxColumn, anyCheckbox);
		final valueLeft:Float = MenuLayout.valueColumn(labelLeft, widestLabel);

		for (i in 0...labels.length)
		{
			final label:Alphabet = labels[i];
			if (label == null) continue;
			final option:Option = (i < options.length) ? options[i] : null;
			final hasCheckbox:Bool = option != null && option.type == 'bool';
			final hasValue:Bool = option != null && option.type != 'bool' && option.type != 'link';

			// `startPosition` is the menu item's home, and `changeX` is off for
			// these rows, so one assignment is all it takes to move a row - even
			// one that is already on screen.
			label.startPosition.x = labelLeft;
			label.x = labelLeft;

			if (hasCheckbox) anchorCheckbox(state, i, labelLeft);
			if (hasValue) anchorValue(state, i, labelLeft, valueLeft);
		}

		state.rowBlockWidth = blockWidth;
	}

	/**
	 * Pins a checkbox one gap to the left of the label column.
	 *
	 * `CheckboxThingie` follows its tracker from `sprTracker.x - 130`, so the
	 * distance is carried in its own `offsetX`: the checkbox starts where the
	 * checkbox column does, whatever the length of the label it belongs to.
	 *
	 * @param labelLeft Where every label of the list starts.
	 */
	static function anchorCheckbox(state:BaseOptionsMenu, index:Int, labelLeft:Float):Void
	{
		for (checkbox in state.checkboxGroup.members)
		{
			if (checkbox == null || checkbox.ID != index) continue;
			checkbox.offsetX = MenuLayout.checkboxOffset(labelLeft, checkbox.width);
			return;
		}
	}

	/**
	 * Pins a value text to the value column.
	 *
	 * `AttachedText` follows its tracker from `sprTracker.x + offsetX`, and the
	 * offset is the distance from the label column to the value column: the same
	 * for every row, which is exactly what makes the values line up even when a
	 * label is shorter than the widest one.
	 */
	static function anchorValue(state:BaseOptionsMenu, index:Int, labelLeft:Float, valueLeft:Float):Void
	{
		final text:AttachedText = valueText(state, index);
		if (text != null) text.offsetX = valueLeft - labelLeft;
	}

	/**
	 * Width of the widest string any of these options can show as its value.
	 *
	 * Values are measured from the option definition - every entry of a `string`
	 * option, the formatted minimum and maximum of a numeric one - so the value
	 * column does not resize while the player scrolls a value.
	 *
	 * @param options The options of the list being laid out.
	 * @return The widest value width in pixels, `0` when no option has a value.
	 */
	static function measureValueColumn(options:Array<Option>):Float
	{
		var widest:Float = 0;

		for (option in options)
		{
			if (option == null || option.type == 'bool' || option.type == 'link') continue;
			for (candidate in valueCandidates(option))
			{
				if (candidate == null) continue;
				widest = Math.max(widest, measureText(candidate));
			}
		}

		return widest;
	}

	/**
	 * Rasterizes `text` with a scratch alphabet and returns its width.
	 *
	 * One instance is reused for every measurement, so laying the list out again
	 * after a resize or a scroll only re-measures the strings that changed. The
	 * scratch alphabet is hidden and non-existent, so it is never updated or
	 * drawn by the menu it measures for.
	 */
	static function measureText(text:String):Float
	{
		if (measureProbe == null)
		{
			measureProbe = new AttachedText('');
			// Not drawn, not updated, not part of any state: it only exists to
			// measure text, so keep it out of the menu's update and draw passes.
			measureProbe.exists = false;
			measureProbe.visible = false;
		}
		// `Alphabet.text` rebuilds its sprite group even when the string is the
		// same, and `centerRows` asks for the same values on every resize.
		if (measureProbe.text != text) measureProbe.text = text;
		return measureProbe.width;
	}

	/** Scratch alphabet used by `measureText`. */
	static var measureProbe:AttachedText = null;

	/**
	 * Drops the cached measuring alphabet, so the next `measureText` builds a new
	 * one against the current font.
	 *
	 * Needed after a style or font change: `Alphabet.reloadAll()` only reloads
	 * groups that exist, and the probe is deliberately non-existent, so it would
	 * otherwise keep the old glyphs and report widths from the previous font.
	 */
	public static function invalidateMeasurements():Void
	{
		if (measureProbe == null) return;
		measureProbe.destroy();
		measureProbe = null;
	}

	/** Every string an option can render as its value. */
	static function valueCandidates(option:Option):Array<String>
	{
		final out:Array<String> = [];
		final format:String = option.displayFormat != null ? option.displayFormat : '%v';

		switch (option.type)
		{
			case 'string':
				if (option.options != null && option.options.length > 0)
				{
					for (entry in option.options) out.push(entry);
					return out;
				}

			case 'int' | 'float' | 'percent':
				for (value in [option.minValue, option.maxValue, option.defaultValue, option.getValue()])
					if (value != null) out.push(renderValue(format, value, option.type));
				return out;

			default:
		}

		final current:Dynamic = option.getValue();
		if (current != null) out.push(Std.string(current));
		return out;
	}

	/** Mirrors `BaseOptionsMenu.updateTextFrom` without touching a live alphabet. */
	static function renderValue(format:String, value:Dynamic, type:String):String
	{
		var shown:Dynamic = value;
		if (type == 'percent') shown = (cast value:Float) * 100;
		return format.replace('%v', Std.string(shown)).replace('%d', Std.string(value));
	}

	static function checkboxWidth(state:BaseOptionsMenu, index:Int):Float
	{
		for (checkbox in state.checkboxGroup.members)
			if (checkbox != null && checkbox.ID == index) return checkbox.width;
		return 0;
	}

	static function valueText(state:BaseOptionsMenu, index:Int):AttachedText
	{
		for (text in state.grpTexts.members)
			if (text != null && text.ID == index) return text;
		return null;
	}
}
