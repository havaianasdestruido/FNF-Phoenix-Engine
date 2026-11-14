package modchart.lab;

/** One of the 34 built-in modifiers, described for the editor UI. */
typedef LabModifier =
{
	/** Registry name (`drunk`, `schmovintornado`, ...) — matches `ModifierRegistry.names()`. */
	var name:String;
	/** Title-cased label shown in the picker. */
	var label:String;
	/** One-line description of what the modifier does. */
	var hint:String;
	/** Draggable percents, main knob first. */
	var knobs:Array<LabKnob>;
}
