package options;

import backend.Controls;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

import backend.ClientPrefs;
import objects.Alphabet;

class Option
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; //bool, int (or integer), float (or fl), percent, string (or str)
	// Bool will use checkboxes
	// Everything else will use a text

	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String = null; //Variable from ClientPrefs.hx
	public var defaultValue:Dynamic = null;

	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var description:String = '';
	public var name:String = 'Unknown';
	public var specialOption:Bool = false;

	/**
	 * Executes the `new` operation.
	 * @param name Input value for `name`.
	 * @param description Input value for `description`.
	 * @param variable Input value for `variable`.
	 * @param type Input value for `type`.
	 * @param defaultValue Input value for `defaultValue`.
	 * @param options Input value for `options`.
	 */
	public function new(name:String, description:String = '', variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String> = null)
	{
		this.name = name;
		this.description = description;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		/*
		if (variable == 'renderPath')
				specialOption = true;
		*/

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
		return Reflect.getProperty(ClientPrefs, variable);
	}
	/**
	 * Executes the `setValue` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `setValue`, when applicable.
	 */
	public function setValue(value:Dynamic)
	{
		Reflect.setProperty(ClientPrefs, variable, value);
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
