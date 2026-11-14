package modchart.lab;

/** One recorded point of a percent automation: the value the lab captured at that (loop-local) beat. */
typedef LabKeyframe =
{
	/** Beat inside the looping section, counted from the section start. */
	var beat:Float;
	/** Percent value recorded at that beat. */
	var value:Float;
}
