package options;

import backend.Controls;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

import backend.ClientPrefs;
import backend.PlatformSupport;
import objects.Alphabet;

class Option
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Void->Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; //bool, int (or integer), float (or fl), percent, string (or str), link (action-only, #45)
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
	 * Build targets this option applies to, as `backend.PlatformSupport` tags
	 * (`['android']`, `['desktop', 'android']`, `['!mobile']`, ...).
	 *
	 * `null` / empty means "no explicit restriction": the option then falls back
	 * to `PlatformSupport.requirementsForPreference()`, so fields that only
	 * exist for some target are still filtered out. `BaseOptionsMenu` drops
	 * unsupported options before they are ever drawn.
	 */
	public var platforms:Array<String> = null;

	public function new(name:String, description:String = '', variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value',
			?options:Array<String> = null, ?platforms:Array<String> = null)
	{
		this.name = name;
		this.description = description;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;
		this.platforms = platforms;

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

		if(type != 'link' && getValue() == null) { // #45
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
	 * Whether this option applies to the running build.
	 *
	 * Explicit `platforms` wins; otherwise the `ClientPrefs` field decides
	 * (e.g. `respectCutout` is Android-only, `mobileCAlpha` mobile-only).
	 */
	public function isSupported():Bool
	{
		if (platforms != null && platforms.length > 0) return PlatformSupport.supports(platforms);
		return PlatformSupport.supportsPreference(variable);
	}

	/** Fluent platform restriction: `new Option(...).onlyOn(['desktop'])`. */
	public function onlyOn(requirements:Array<String>):Option
	{
		platforms = requirements;
		return this;
	}

	public function change()
	{
		//nothing lol
		if(onChange != null) {
			onChange();
		}
	}

	public function getValue():Dynamic
	{
		if (type == 'link') return null; // #45: link options carry no value
		return Reflect.getProperty(ClientPrefs, variable);
	}
	public function setValue(value:Dynamic)
	{
		if (type == 'link') return; // #45
		Reflect.setProperty(ClientPrefs, variable, value);
	}

	public function setChild(child:Alphabet)
	{
		this.child = child;
	}

	/**
	 * Name of the `ClientPrefs` field this option edits (empty for `link`
	 * options). Used by the menu to explain when a memory profile is forcing
	 * the value; see `backend.LowMemory.isManaged`.
	 */
	public function prefName():String
		return variable == null ? '' : variable;

	private function get_text()
	{
		if(child != null) {
			return child.text;
		}
		return null;
	}
	private function set_text(newValue:String = '')
	{
		if(child != null) {
			child.text = newValue;
		}
		return null;
	}

	private function get_type()
	{
		var newValue:String = 'bool';
		switch(type.toLowerCase().trim())
		{
			case 'link': newValue = 'link'; // #45: action-only option, no ClientPrefs field
			case 'int' | 'float' | 'percent' | 'string': newValue = type;
			case 'integer': newValue = 'int';
			case 'str': newValue = 'string';
			case 'fl': newValue = 'float';
		}
		type = newValue;
		return type;
	}
}
