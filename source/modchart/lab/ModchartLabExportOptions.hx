package modchart.lab;

/**
 * Settings for one export: which language, which slice of the timeline and
 * how the section should behave.
 *
 * Beats are song beats; `startBeat`/`length` describe the looping section the
 * lab was auditioning. Tracks store loop-local beats, so this is the only
 * place the section offset is applied.
 */
class ModchartLabExportOptions
{
	/** Target language; mirrors the Lua/Python API parity. */
	public var language:LabLanguage = Lua;

	/** Song beat the section starts on. */
	public var startBeat:Float = 0;

	/** Section length in beats (kept positive by the exporter). */
	public var length:Float = 8;

	/** Ease applied to every generated `modEase` (`quadOut`, `sineInOut`, ...). */
	public var ease:String = 'quadOut';

	/** `true` exports a `modRepeater` + callback pair that repeats the section for the whole song. */
	public var loop:Bool = false;

	/** Callback the loop mode schedules. */
	public var callbackName:String = 'onModchartLabSection';

	/** Creates options with the lab's defaults. */
	public function new()
	{
	}
}
