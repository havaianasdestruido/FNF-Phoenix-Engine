package play;

import modchart.ModchartManager;
import objects.Note;
import objects.StrumNote;

/**
 * Stand-in for `play.PlayState` exposing only what the modchart runtime
 * adapter touches. Group iteration mirrors Flixel's `forEachAlive`.
 */
class PlayState
{
	public static var instance:PlayState;

	public var modchart:ModchartManager = null;
	public var songSpeed:Float = 1;
	public var curDecBeat:Float = 0;
	public var strumLineNotes:ModchartStubGroup<StrumNote> = new ModchartStubGroup();
	public var playerStrums:ModchartStubGroup<StrumNote> = new ModchartStubGroup();
	public var opponentStrums:ModchartStubGroup<StrumNote> = new ModchartStubGroup();
	public var notes:ModchartStubGroup<Note> = new ModchartStubGroup();
	public var sustainNotes:ModchartStubGroup<Note> = new ModchartStubGroup();

	public function new() {}

	public function callOnLuas(event:String, args:Array<Dynamic> = null):Dynamic
	{
		return null;
	}
}

private class ModchartStubGroup<T>
{
	public var members:Array<T> = [];

	public function new() {}

	public function forEachAlive(func:T->Void):Void
	{
		for (member in members)
			func(member);
	}
}
