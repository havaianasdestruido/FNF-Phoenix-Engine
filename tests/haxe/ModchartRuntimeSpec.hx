import backend.Conductor;
import objects.Note;
import objects.StrumNote;
import play.PlayState;
import play.helpers.PlayStateModchart;
import psychlua.FunkinLua;
import psychlua.PythonScript;
import psychlua.callbacks.ModchartCallbacks;
import psychlua.pystdlib.PyModchartLib;

/**
 * Runtime-adapter contract tests for `play.helpers.PlayStateModchart` plus
 * the Lua/Python callback registration, against renderer-free stubs.
 * Run by `tests/haxe/run-modchart-typecheck.sh`.
 */
class ModchartRuntimeSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok)
			throw label;
	}

	static function makeState(?lanes:Int = 4):PlayState
	{
		final state:PlayState = new PlayState();
		PlayState.instance = state;
		for (player in 0...2)
		{
			for (lane in 0...lanes)
			{
				final strum:StrumNote = new StrumNote();
				strum.x = 100 + lane * 100 + player * 600;
				strum.y = 50;
				strum.noteData = lane;
				strum.player = player;
				state.strumLineNotes.members.push(strum);
				if (player == 0)
					state.opponentStrums.members.push(strum);
				else
					state.playerStrums.members.push(strum);
			}
		}
		return state;
	}

	static function main():Void
	{
		// Callback registration must not crash against the stub hosts.
		ModchartCallbacks.register(new FunkinLua());
		PyModchartLib.register(new PythonScript());

		final state:PlayState = makeState();
		Conductor.songPosition = 0;
		Conductor.crochet = 600;
		state.curDecBeat = 0;

		PlayStateModchart.setup(state);
		check(state.modchart != null, 'setup creates the manager');
		check(!PlayStateModchart.isActive(state), 'idle before any modifier');

		// Inactive updates only track defaults; strums stay put.
		PlayStateModchart.updateStrums(state, 0.016);
		check(state.strumLineNotes.members[0].x == 100, 'inactive strums untouched');

		state.modchart.addModifier('transform');
		state.modchart.setPercent('x', 30, -1);
		check(PlayStateModchart.isActive(state), 'active after addModifier');

		PlayStateModchart.updateStrums(state, 0.016);
		check(state.strumLineNotes.members[0].x == 130, 'transform shifts receptors');
		check(state.strumLineNotes.members[7].x == 1030, 'transform shifts every receptor');

		// Notes follow the moved strums, then take their own offset.
		final note:Note = new Note();
		note.x = 130;
		note.y = -150;
		note.noteData = 0;
		note.mustPress = false;
		note.strumTime = 1000;
		state.notes.members.push(note);
		PlayStateModchart.updateNotes(state);
		check(note.x == 160, 'note inherits strum move plus its own offset');
		note.x = 130; // followStrum rewrites this every frame
		PlayStateModchart.updateNotes(state);
		check(note.x == 160, 'note transforms do not accumulate across frames');

		// Notes that opt out of copying a field must not receive that offset.
		final pinned:Note = new Note();
		pinned.x = 500;
		pinned.y = -150;
		pinned.noteData = 1;
		pinned.mustPress = true;
		pinned.strumTime = 1000;
		pinned.copyX = false;
		state.notes.members.push(pinned);
		PlayStateModchart.updateNotes(state);
		check(pinned.x == 500, 'copyX = false keeps the note off the x transform');

		// Reset restores receptors and clears the timeline.
		PlayStateModchart.reset(state);
		check(state.strumLineNotes.members[0].x == 100, 'reset restores receptors');
		check(!state.modchart.isActive(), 'reset clears modifiers');

		// External changes (intro alpha tween, setProperty) survive the modchart.
		final cooperation:PlayState = makeState();
		PlayStateModchart.setup(cooperation);
		cooperation.modchart.addModifier('transform');
		cooperation.modchart.setPercent('x', 10, -1);
		cooperation.modchart.addModifier('stealth');
		cooperation.modchart.addModifier('scale');
		final strum:StrumNote = cooperation.strumLineNotes.members[0];
		strum.alpha = 0.5;
		PlayStateModchart.updateStrums(cooperation, 0.016);
		check(strum.alpha == 0.5, 'neutral visuals keep externally tweened alpha');
		cooperation.modchart.setPercent('alpha', 0.5, -1);
		PlayStateModchart.updateStrums(cooperation, 0.016);
		check(strum.alpha == 0.25, 'alpha modifier composes with the external value');
		cooperation.modchart.setPercent('alpha', 1, -1);
		PlayStateModchart.updateStrums(cooperation, 0.016);
		check(strum.alpha == 0.5, 'clearing the alpha modifier restores the external value');
		cooperation.modchart.setPercent('scale', 2, -1);
		PlayStateModchart.updateStrums(cooperation, 0.016);
		check(strum.scale.x == 2, 'scale modifier multiplies the resting scale');
		cooperation.modchart.setPercent('scale', 1, -1);
		PlayStateModchart.updateStrums(cooperation, 0.016);
		check(strum.scale.x == 1, 'clearing the scale modifier restores the resting scale');

		// Wider charts: the lane count follows the live strum groups.
		final wide:PlayState = makeState(5);
		PlayStateModchart.setup(wide);
		check(wide.modchart.playfields[0].keyCount == 5, 'key count follows the strum groups');
		check(wide.modchart.playfields[0].receptorX[1][4] == 100 + 4 * 100 + 600, 'extra lanes keep their receptor position');

		Sys.println('ModchartRuntimeSpec: PASS');
	}
}
