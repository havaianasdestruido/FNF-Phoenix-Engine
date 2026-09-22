package states.substates;

import backend.ClientPrefs;
import backend.Controls;
import backend.MusicBeatSubstate;
import backend.Paths;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import objects.Alphabet;
import objects.AttachedText;
import objects.CheckboxThingie;
import play.PlayState;
import headers.States;

class GameplayChangersSubstate extends MusicBeatSubstate
{
	private var curOption:GameplayOption = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Dynamic> = [];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;
	public static var inThePauseMenu:Bool = false;
	public var pauseState:PauseSubState;

	/**
	 * Executes the `getOptions` operation.
	 * @return Result produced by `getOptions`, when applicable.
	 */
	function getOptions()
	{
		GameplayChangersHelpers.getOptions(this);
	}

	/**
	 * Executes the `getOptionByName` operation.
	 * @param name Input value for `name`.
	 * @return Result produced by `getOptionByName`, when applicable.
	 */
	public function getOptionByName(name:String)
	{
		return GameplayChangersHelpers.getOptionByName(this, name);
	}

	/**
	 * Executes the `new` operation.
	 * @param pause Input value for `pause`.
	 */
	public function new(?pause:MusicBeatSubstate = null)
	{
		super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		getOptions();

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(200, 360, optionsArray[i].name, true);
			optionText.isMenuItem = true;
			optionText.setScale(0.8);
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == 'bool') {
				optionText.x += 90;
				optionText.startPosition.x += 90;
				optionText.snapToPosition();
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.offsetX -= 20;
				checkbox.offsetY = -52;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			} else {
				optionText.snapToPosition();
				var valueText:AttachedText = new AttachedText(Std.string(optionsArray[i].getValue()), optionText.width + 40, 0, true, 0.8);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	/**
	 * Executes the `destroy` operation.
	 * @return Result produced by `destroy`, when applicable.
	 */
	override function destroy() {
		if (inThePauseMenu)  {
			PlayState.instance.changeTheSettingsBitch();
			inThePauseMenu = false;
		}
		super.destroy();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			close();
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			var usesCheckbox = true;
			if(curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if(usesCheckbox)
			{
				if(controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			} else {
				if(controls.UI_LEFT || controls.UI_RIGHT) {
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if(holdTime > 0.5 || pressed) {
						if(pressed) {
							var add:Dynamic = null;

							if(curOption.type != 'string') {
								var step:Float = curOption.changeValue;

								if (FlxG.keys.pressed.CONTROL)
									step = curOption.slowChangeVal;
								else if (FlxG.keys.pressed.SHIFT)
								{
									if(curOption.type == 'int')
										step = 5;
									else
										step = 1;
								}

								add = controls.UI_LEFT ? -step : step;
							}

							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if(holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.curOption; //lol
									if(controls.UI_LEFT_P) --num;
									else num++;

									if(num < 0) {
										num = curOption.options.length - 1;
									} else if(num >= curOption.options.length) {
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol

									if (curOption.name == "Scroll Type")
									{
										var oOption:GameplayOption = getOptionByName("Scroll Speed");
										if (oOption != null)
										{
											if (curOption.getValue() == "constant")
											{
												oOption.displayFormat = "%v";
												oOption.maxValue = 1024;
											}
											else
											{
												oOption.displayFormat = "%vX";
												oOption.maxValue = 128;
												if(oOption.getValue() > 128) oOption.setValue(128);
											}
											updateTextFrom(oOption);
										}
									}
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'));
						} else if(curOption.type != 'string') {
							holdValue += curOption.scrollSpeed * elapsed * curOption.getValue() * (controls.UI_LEFT ? -1 : 1);
							if (holdValue < curOption.minValue) holdValue = curOption.minValue;
							if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));

								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if(curOption.type != 'string') {
						holdTime += elapsed;
					}
				} else if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					clearHold();
				}
			}
			if(controls.RESET && FlxG.keys.pressed.SHIFT)
			{
				for (i in 0...optionsArray.length)
				{
					var leOption:GameplayOption = optionsArray[i];
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != 'bool')
					{
						if(leOption.type == 'string')
						{
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						}
						updateTextFrom(leOption);
					}

					if(leOption.name == 'Scroll Speed')
					{
						leOption.displayFormat = "%vX";
						leOption.maxValue = 60;
						if(leOption.getValue() > 60)
						{
							leOption.setValue(60);
						}
						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}

			if(controls.RESET && !FlxG.keys.pressed.SHIFT)
			{
				var leOption:GameplayOption = optionsArray[curSelected];
				leOption.setValue(leOption.defaultValue);
				if(leOption.type != 'bool')
				{
					if(leOption.type == 'string')
					{
						leOption.curOption = leOption.options.indexOf(leOption.getValue());
					}
					updateTextFrom(leOption);
				}

				if(leOption.name == 'Scroll Speed')
				{
					leOption.displayFormat = "%vX";
					leOption.maxValue = 128;
					if(leOption.getValue() > 128)
					{
						leOption.setValue(128);
					}
					updateTextFrom(leOption);
				}
				leOption.change();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	/**
	 * Executes the `updateTextFrom` operation.
	 * @param option Input value for `option`.
	 * @return Result produced by `updateTextFrom`, when applicable.
	 */
	function updateTextFrom(option:GameplayOption) {
		GameplayChangersHelpers.updateTextFrom(option);
	}

	/**
	 * Executes the `clearHold` operation.
	 * @return Result produced by `clearHold`, when applicable.
	 */
	function clearHold()
	{
		GameplayChangersHelpers.clearHold(this);
	}

	/**
	 * Executes the `onChangeChartOption` operation.
	 * @return Result produced by `onChangeChartOption`, when applicable.
	 */
	function onChangeChartOption()
	{
		GameplayChangersHelpers.onChangeChartOption(this);
	}
	/**
	 * Executes the `onChangeCheat` operation.
	 * @return Result produced by `onChangeCheat`, when applicable.
	 */
	function onChangeCheat()
	{
		GameplayChangersHelpers.onChangeCheat(this);
	}

	/**
	 * Executes the `changeSelection` operation.
	 * @param change Input value for `change`.
	 * @return Result produced by `changeSelection`, when applicable.
	 */
	function changeSelection(change:Int = 0)
	{
		GameplayChangersHelpers.changeSelection(this, change);
	}

	/**
	 * Executes the `reloadCheckboxes` operation.
	 * @return Result produced by `reloadCheckboxes`, when applicable.
	 */
	function reloadCheckboxes() {
		GameplayChangersHelpers.reloadCheckboxes(this);
	}
}

class GameplayOption
{
	private var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; //bool, int (or integer), float (or fl), percent, string (or str)
	// Bool will use checkboxes
	// Everything else will use a text

	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; //Variable from ClientPrefs.hx's gameplaySettings
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var slowChangeVal:Dynamic = 1; //how much is changed when you PRESS while holding CONTROL
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var name:String = 'Unknown';

	/**
	 * Executes the `new` operation.
	 * @param name Input value for `name`.
	 * @param variable Input value for `variable`.
	 * @param type Input value for `type`.
	 * @param defaultValue Input value for `defaultValue`.
	 * @param options Input value for `options`.
	 */
	public function new(name:String, variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String> = null)
	{
		this.name = name;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if(defaultValue == 'null variable value')
		{
			switch(type)
			{
				case 'bool':
					defaultValue = false;
				case 'int' | 'float':
					defaultValue = 0;
				case 'percent':
					defaultValue = 1;
				case 'string':
					defaultValue = '';
					if(options.length > 0) {
						defaultValue = options[0];
					}
			}
		}

		if(getValue() == null) {
			setValue(defaultValue);
		}

		switch(type)
		{
			case 'string':
				var num:Int = options.indexOf(getValue());
				if(num > -1) {
					curOption = num;
				}

			case 'percent':
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	/**
	 * Executes the `change` operation.
	 * @return Result produced by `change`, when applicable.
	 */
	public function change()
	{
		//nothing lol
		if(onChange != null) {
			onChange();
		}
	}

	/**
	 * Executes the `getValue` operation.
	 * @return Result produced by `getValue`, when applicable.
	 */
	public function getValue():Dynamic
	{
		return ClientPrefs.gameplaySettings.get(variable);
	}
	/**
	 * Executes the `setValue` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `setValue`, when applicable.
	 */
	public function setValue(value:Dynamic)
	{
		ClientPrefs.gameplaySettings.set(variable, value);
	}

	/**
	 * Executes the `setChild` operation.
	 * @param child Input value for `child`.
	 * @return Result produced by `setChild`, when applicable.
	 */
	public function setChild(child:Alphabet)
	{
		this.child = child;
	}

	/**
	 * Executes the `get_text` operation.
	 * @return Result produced by `get_text`, when applicable.
	 */
	private function get_text()
	{
		if(child != null) {
			return child.text;
		}
		return null;
	}
	/**
	 * Executes the `set_text` operation.
	 * @param newValue Input value for `newValue`.
	 * @return Result produced by `set_text`, when applicable.
	 */
	private function set_text(newValue:String = '')
	{
		if(child != null) {
			child.text = newValue;
		}
		return null;
	}

	/**
	 * Executes the `get_type` operation.
	 * @return Result produced by `get_type`, when applicable.
	 */
	private function get_type()
	{
		var newValue:String = 'bool';
		switch(type.toLowerCase().trim())
		{
			case 'int' | 'float' | 'percent' | 'string': newValue = type;
			case 'integer': newValue = 'int';
			case 'str': newValue = 'string';
			case 'fl': newValue = 'float';
		}
		type = newValue;
		return type;
	}
}
