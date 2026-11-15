package modchart.lab;

/** One draggable percent of a modifier: the slider the lab paints for it. */
typedef LabKnob =
{
	/** Percent name as scripts spell it (`drunkX`, `bounceOffset`, ...). Storage stays case-insensitive. */
	var percent:String;
	/** Slider lower bound, in the percent's own unit (pixels, degrees, multiplier). */
	var min:Float;
	/** Slider upper bound. */
	var max:Float;
	/** Keyboard nudge: one press of the adjust keys moves the value by this much. */
	var step:Float;
	/** The value the modifier ships with, restored by `ENTER` on the slider. */
	var value:Float;
	/** True for the single knob that shows the modifier at a glance (the lab's list preview reads it). */
	var main:Bool;
}
