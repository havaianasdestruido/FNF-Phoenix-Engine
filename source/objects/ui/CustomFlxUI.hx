package objects.ui;

import backend.CoolUtil;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITypedButton;
import flixel.addons.ui.StrNameLabel;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import openfl.events.KeyboardEvent;

/**
 * Dark-themed flixel-ui widget classes, ported from FNF-Troll-Engine:
 * https://github.com/troll-slaiyers/FNF-Troll-Engine (commit 741ca3e "flixel-ui dark mode")
 *
 * Together with the dark chrome/button/check/radio/tab sprites in assets/flixel-ui-dark/ -- which
 * source/source-haxelib-patches/flixel/addons/ui/FlxUIAssets.hx points flixel-ui's IMG_* constants
 * at, so the haxelib's own widgets are re-skinned too -- these classes give the editor UI a
 * consistent dark look:
 *   - Input text / numeric stepper / dropdown header backgrounds use a dark slate (0xFF383A46)
 *   - Text and caret colors are white for contrast
 *   - Plus/minus and tab label colors are forced to white
 *   - Mouse wheel is supported on sliders, numeric steppers, and dropdown headers
 *   - Numeric steppers don't commit changes until Enter / focus lost (Troll Engine behavior)
 */

private inline final TEXT_BG_COLOR:Int = 0xFF383A46;

private function setupInputText(fit:FlxInputText):Void
{
	fit.backgroundColor = TEXT_BG_COLOR;
	fit.color = FlxColor.WHITE;
	fit.caretColor = FlxColor.WHITE;
}

/**
 * Tab menu that preserves insertion order (Troll Engine comment: "dont sort my shit").
 */
class CustomFlxUITabMenu extends FlxUITabMenu
{
	override function sortTabs(a, b):Int
		return 0;
}

/**
 * FlxInputText (native text field) with dark background, white text/caret, and keyboard
 * event handling that stops propagation while focused so Flixel hotkeys don't fire while typing.
 */
class CustomFlxInputText extends FlxInputText
{
	public function new(X:Float = 0, Y:Float = 0, Width:Int = 150, ?Text:String, size:Int = 8, TextColor:Int = FlxColor.WHITE,
		BackgroundColor:Int = TEXT_BG_COLOR, EmbeddedFont:Bool = true)
	{
		super(X, Y, Width, Text, size, TextColor, BackgroundColor, EmbeddedFont);
		setupInputText(this);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 100); // higher priority than flixel
	}

	override function onKeyDown(e)
	{
		super.onKeyDown(e);
		if (hasFocus) e.stopImmediatePropagation();
	}

	override function destroy()
	{
		super.destroy();
	}
}

/**
 * FlxUIInputText with the same dark styling and keyboard event priority as CustomFlxInputText.
 */
class CustomFlxUIInputText extends FlxUIInputText
{
	public function new(X:Float = 0, Y:Float = 0, Width:Int = 150, ?Text:String, size:Int = 8, TextColor:Int = FlxColor.WHITE,
		BackgroundColor:Int = TEXT_BG_COLOR, EmbeddedFont:Bool = true)
	{
		super(X, Y, Width, Text, size, TextColor, BackgroundColor, EmbeddedFont);
		setupInputText(this);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 100); // higher priority than flixel
	}

	override function onKeyDown(e)
	{
		super.onKeyDown(e);
		if (hasFocus) e.stopImmediatePropagation();
	}

	override function destroy()
	{
		super.destroy();
	}
}

/**
 * Numeric stepper that:
 *  - Uses a dark-themed text field (or re-colors the default one)
 *  - Colors plus/minus labels white for dark chrome
 *  - Allows mouse-wheel changes while hovering the text field
 *  - Only commits the typed value on Enter / focus lost
 */
class CustomFlxUINumericStepper extends FlxUINumericStepper
{
	public var hoveringText:Bool = false;

	public var callback:(value:Float, action:String) -> Void;

	public function new(X:Float = 0, Y:Float = 0, StepSize:Float = 1, DefaultValue:Float = 0, Min:Float = -999, Max:Float = 999, Decimals:Int = 0,
			Stack:Int = FlxUINumericStepper.STACK_HORIZONTAL, ?TextField:FlxText, ?ButtonPlus:FlxUITypedButton<FlxSprite>, ?ButtonMinus:FlxUITypedButton<FlxSprite>,
			IsPercent:Bool = false)
	{
		TextField ??= new CustomFlxUIInputText(0, 0, 25);

		super(X, Y, StepSize, DefaultValue, Min, Max, Decimals, Stack, TextField, ButtonPlus, ButtonMinus, IsPercent);

		if (text_field is FlxInputText)
			setupInputText(cast text_field);
		if (ButtonPlus == null)
			button_plus.label.color = FlxColor.WHITE;
		if (ButtonMinus == null)
			button_minus.label.color = FlxColor.WHITE;

		if ((text_field is FlxUIInputText))
		{
			var fuit:FlxUIInputText = cast text_field;
			fuit.focusLost = _onInputTextLostFocus.bind(fuit);
		}
	}

	override function update(elapsed:Float)
	{
		if (hoveringText = FlxG.mouse.overlaps(text_field, text_field.camera))
		{
			if (FlxG.mouse.wheel > 0) _onPlus();
			else if (FlxG.mouse.wheel < 0) _onMinus();
		}
		super.update(elapsed);
	}

	override function _onInputTextEvent(text:String, action:String):Void
	{
		if (action != FlxInputText.ENTER_ACTION)
			return;

		super._onInputTextEvent(text, action);
	}

	function _onInputTextLostFocus(fuit:FlxUIInputText):Void
	{
		value = Std.parseFloat(fuit.text);
		_doCallback(FlxUINumericStepper.EDIT_EVENT);
		_doCallback(FlxUINumericStepper.CHANGE_EVENT);
	}

	override function _doCallback(event_name:String)
	{
		if (callback != null) callback(value, event_name);
		return super._doCallback(event_name);
	}
}

/**
 * Drop-down menu that:
 *  - Uses a dark header background with white text
 *  - Supports scrolling through options with the mouse wheel while the header is highlighted
 *    (without having to open the drop panel).
 */
class CustomFlxUIDropDownMenu extends objects.FlxUIDropDownMenuCustom
{
	public function new(X:Float = 0, Y:Float = 0, DataList:Array<StrNameLabel>, ?Callback:String->Void,
			?Header:objects.FlxUIDropDownMenuCustom.FlxUIDropDownHeader, ?DropPanel:FlxUI9SliceSprite,
			?ButtonList:Array<FlxUIButton>, ?UIControlCallback:Bool->objects.FlxUIDropDownMenuCustom->Void)
	{
		super(X, Y, DataList, Callback, Header, DropPanel, ButtonList, UIControlCallback);
		header.background.color = TEXT_BG_COLOR;
		header.text.color = FlxColor.WHITE;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!dropPanel.visible && header.button.status == FlxButton.HIGHLIGHT && FlxG.mouse.wheel != 0)
		{
			var idx:Int = 0;
			for (i => btn in list)
			{
				if (btn.label.text != selectedLabel) continue;
				idx = i;
				break;
			}
			idx = CoolUtil.clampIndex(idx - Std.int(FlxG.mouse.wheel), list.length);
			selectItemByIndex(idx);
		}
	}
}

/**
 * Slider that lets the user drag and also scroll with the mouse wheel while hovering the handle.
 */
class CustomFlxUISlider extends FlxUISlider
{
	public var scrollStep:Float = 0.1;

	override function update(elapsed)
	{
		// FlxSlider has no `dragging` field: like FlxSlider.update() itself,
		// treat a held mouse button as "being dragged" and skip the wheel so the
		// two input paths cannot fight over `value` in the same frame.
		if (_justHovered && !FlxG.mouse.pressed && scrollStep != 0.0 && FlxG.mouse.wheel != 0)
		{
			var relativePos:Float = this.relativePos + FlxG.mouse.wheel * scrollStep;

			value = minValue + (maxValue - minValue) * relativePos;
			if (value < minValue) value = minValue;
			else if (value > maxValue) value = maxValue;

			if ((setVariable) && (varString != null))
			{
				Reflect.setProperty(_object, varString, value);
			}

			_lastPos = relativePos;

			if (callback != null)
				callback(relativePos);

			handle.x = expectedPos;
		}

		super.update(elapsed);
	}
}
