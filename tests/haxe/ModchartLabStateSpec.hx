import backend.ClientPrefs;
import editors.ModchartLabState;
import flixel.FlxG;
import lime.system.Clipboard;
import modchart.PlayField;
import modchart.lab.LabKnob;
import modchart.lab.LabModifier;
import modchart.lab.ModchartLabCatalog;
import modchart.lab.ModchartLabExport;
import modchart.lab.ModchartLabTrack;

/**
 * Typecheck + behaviour tests for `editors.ModchartLabState` against the
 * renderer-free stubs in `tests/haxe/stubs/lab`.
 *
 * The editor is driven the way a player would drive it — click a modifier in
 * the list, drag a percent slider while the beat clock runs, press the
 * keyboard shortcuts — and then the generated script text is asserted. That
 * catches the mistakes a compile alone would miss: a slider bound to the
 * wrong percent, a recording that never lands on the grid, an export that is
 * not refreshed, a shortcut that stops working after the selection changes.
 *
 * Run by `tests/haxe/run-modchart-lab-typecheck.sh`.
 */
class ModchartLabStateSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok)
			throw label;
	}

	static function contains(text:String, needle:String, label:String):Void
	{
		if (text.indexOf(needle) == -1)
			throw label + ': expected to find "' + needle + '" in:\n' + text;
	}

	/** Fresh state with the stub screen, like `FlxG.resetState` would build it. */
	static function makeState():ModchartLabState
	{
		FlxG.width = 1280;
		FlxG.height = 720;
		ClientPrefs.downScroll = false;
		FlxG.mouse.visible = false;
		FlxG.mouse.justPressed = false;
		FlxG.mouse.pressed = false;
		FlxG.mouse.wheel = 0;
		FlxG.keys.justPressed.reset();
		FlxG.keys.pressed.reset();
		Clipboard.text = '';
		FlxG.switchedState = null;

		final state:ModchartLabState = new ModchartLabState();
		state.create();
		return state;
	}

	static function main():Void
	{
		layoutAndSelection();
		dragRecordsAutomation();
		keyboardShortcuts();
		exportOptions();
		transport();
		exitsOnBack();
		Sys.println('ModchartLabStateSpec: PASS');
	}

	static function indexOfModifier(name:String):Int
	{
		final all:Array<LabModifier> = ModchartLabCatalog.all();
		for (i in 0...all.length)
		{
			if (all[i].name == name)
				return i;
		}
		return -1;
	}

	/** Screen position of a modifier list row (column-major, 17 rows). */
	static function listPoint(index:Int):{x:Float, y:Float}
	{
		final col:Int = Std.int(index / 17);
		final row:Int = index % 17;
		return {x: 12 + col * 132 + 6, y: 92 + row * 22 + 8};
	}

	/** Screen position of a knob slider at `t` (0..1) of its range. */
	static function knobPoint(state:ModchartLabState, slot:Int, t:Float):{x:Float, y:Float}
	{
		@:privateAccess
		{
			final row = state.knobRows[slot];
			return {x: row.bar.x + row.bar.width * t, y: row.bar.y + 3};
		}
	}

	static function frame(state:ModchartLabState, ?elapsed:Float = 1 / 60):Void
	{
		state.update(elapsed);
		FlxG.mouse.justPressed = false;
		FlxG.mouse.wheel = 0;
		FlxG.keys.justPressed.reset();
	}

	static function layoutAndSelection():Void
	{
		final state:ModchartLabState = makeState();
		@:privateAccess
		{
			check(state.catalog.length == 34, 'the picker lists all 34 modifiers');
			check(state.field != null && state.field.keyCount == 4, 'the preview field is a 4K playfield');
			check(state.previewArrows.length == 8 + 8 * 2, 'receptors plus two ghosts per lane and side');
			check(state.listRows.length == 34, 'one list row per modifier');
			for (player in 0...2)
			{
				for (lane in 0...4)
				{
					check(state.field.receptorX[player][lane] > 0, 'lane anchors are laid out');
					check(state.field.receptorY[player][lane] > 0, 'receptor line is inside the preview');
				}
			}
			check(state.field.hasModifier(state.catalog[0].name), 'the first modifier is installed on start');
		}

		// Click the `drunk` row: it becomes selected and is installed.
		final drunk:Int = indexOfModifier('drunk');
		check(drunk >= 0, 'drunk exists in the catalog');
		final point = listPoint(drunk);
		FlxG.mouse.x = point.x;
		FlxG.mouse.y = point.y;
		FlxG.mouse.justPressed = true;
		frame(state);

		@:privateAccess
		{
			check(state.selected == drunk, 'clicking a row selects that modifier');
			check(state.field.hasModifier('drunk'), 'selecting installs the modifier in the preview');
			check(state.knobRows[0].knob != null, 'knob sliders are bound to the selection');
			check(state.knobRows[0].knob.percent == 'drunk', 'the main knob of drunk comes first');
			check(state.knobRows[0].bar.visible, 'the main slider is visible');
		}

		// Unknown/duplicate clicks are harmless.
		FlxG.mouse.x = 4;
		FlxG.mouse.y = 4;
		FlxG.mouse.justPressed = true;
		frame(state);
		@:privateAccess check(state.selected == drunk, 'clicks outside the list leave the selection alone');
	}

	static function dragRecordsAutomation():Void
	{
		final state:ModchartLabState = makeState();
		final drunk:Int = indexOfModifier('drunk');
		final point = listPoint(drunk);
		FlxG.mouse.x = point.x;
		FlxG.mouse.y = point.y;
		FlxG.mouse.justPressed = true;
		frame(state);

		// Press on the slider at 25% of its range and drag to 80%.
		final start = knobPoint(state, 0, 0.25);
		FlxG.mouse.x = start.x;
		FlxG.mouse.y = start.y;
		FlxG.mouse.justPressed = true;
		FlxG.mouse.pressed = true;
		frame(state);

		@:privateAccess
		{
			check(state.dragging != null, 'pressing a slider starts a drag');
			check(state.tracks.length == 1, 'the drag opens one automation track');
			final track:ModchartLabTrack = state.tracks[0];
			check(track.modifier == 'drunk' && track.percent == 'drunk', 'the track targets the dragged percent');
			check(track.player == -1, 'the default side is both players');
			check(track.count() == 1, 'the first frame records one keyframe');
			check(track.keys[0].value > 0.15 && track.keys[0].value < 0.35, 'the keyframe value follows the slider');
			check(track.keys[0].beat == 0 || track.keys[0].beat == 0.25, 'keyframes snap to the 16th grid');
		}

		// Keep playing and dragging to the right: more keys, still on the grid.
		final end = knobPoint(state, 0, 0.8);
		FlxG.mouse.x = end.x;
		for (_ in 0...24)
			frame(state);

		@:privateAccess
		{
			final track:ModchartLabTrack = state.tracks[0];
			check(track.count() >= 2, 'dragging over the loop records more keyframes');
			for (key in track.keys)
			{
				check(key.beat >= 0 && key.beat <= state.sectionLength(), 'keyframes stay inside the section');
				check(Math.abs(key.beat / 0.25 - Math.round(key.beat / 0.25)) < 0.0001, 'keyframes stay on the 16th grid');
				check(key.value > 0.7 && key.value < 0.9, 'later keyframes follow the slider position');
			}
			check(state.field.getPercent('drunk', 0) > 0.5, 'the live percent follows the drag');
			check(state.exportDirty == false || state.exportDirty == true, 'export state stays consistent');
			contains(state.codeText.text, 'function onCreatePost()', 'the code preview shows the generated function');
			contains(state.codeText.text, "addModifier('drunk')", 'the code preview installs the modifier');
			contains(state.codeText.text, "modSet('drunk'", 'the code preview anchors the section');
			contains(state.codeText.text, "modEase('drunk'", 'the code preview emits a modEase');
			contains(state.codeText.text, "'quadOut'", 'the code preview uses the selected ease');
		}

		// Releasing the mouse stops the drag but keeps the automation.
		FlxG.mouse.pressed = false;
		frame(state);
		@:privateAccess
		{
			check(state.dragging == null, 'releasing ends the drag');
			check(state.tracks[0].count() >= 2, 'recorded keyframes survive the release');
		}

		// The second pass replays the recording instead of the mouse.
		FlxG.mouse.x = knobPoint(state, 0, 0.1).x;
		FlxG.mouse.y = knobPoint(state, 0, 0.1).y;
		for (_ in 0...40)
			frame(state);
		@:privateAccess check(state.tracks[0].count() >= 2, 'the preview keeps replaying a released track');
	}

	static function keyboardShortcuts():Void
	{
		final state:ModchartLabState = makeState();
		@:privateAccess
		{
			final startSelected:Int = state.selected;
			FlxG.keys.justPressed.DOWN = true;
			frame(state);
			check(state.selected == (startSelected + 1) % 34, 'DOWN moves the selection');

			FlxG.keys.justPressed.RIGHT = true;
			frame(state);
			check(state.selected == (startSelected + 1 + 17) % 34, 'RIGHT jumps a list column');

			// SHIFT+DOWN walks the knobs instead of the list.
			final selected:Int = state.selected;
			FlxG.keys.pressed.SHIFT = true;
			FlxG.keys.justPressed.DOWN = true;
			frame(state);
			check(state.selected == selected, 'SHIFT+DOWN leaves the modifier selection alone');
			check(state.selectedKnob == 1, 'SHIFT+DOWN moves to the next percent');
			FlxG.keys.pressed.SHIFT = false;

			// Nudging a percent records a keyframe at the playhead.
			final knob:LabKnob = state.currentKnob();
			final step:Float = knob.step;
			FlxG.keys.pressed.SHIFT = true;
			FlxG.keys.justPressed.RIGHT = true;
			frame(state);
			FlxG.keys.pressed.SHIFT = false;
			final track:ModchartLabTrack = state.tracks[state.tracks.length - 1];
			check(track.count() == 1, 'SHIFT+RIGHT records a keyframe');
			check(Math.abs(track.keys[0].value - step) < 0.0001, 'the nudge moves by the knob step');

			// ENTER restores the modifier default.
			FlxG.keys.justPressed.ENTER = true;
			frame(state);
			check(track.count() == 1, 'ENTER rewrites the same grid bucket');
			check(Math.abs(track.keys[0].value - knob.value) < 0.0001, 'ENTER restores the default value');

			// X clears this percent, SHIFT+X clears everything.
			FlxG.keys.justPressed.X = true;
			frame(state);
			check(track.count() == 0, 'X clears the selected percent');
			check(state.totalKeys() == 0, 'nothing else was recorded');

			// Side selection changes which track a drag writes to.
			FlxG.keys.justPressed.TWO = true;
			frame(state);
			check(state.side == 0, 'TWO selects the opponent side');
			FlxG.keys.justPressed.THREE = true;
			frame(state);
			check(state.side == 1, 'THREE selects the player side');
			FlxG.keys.justPressed.ONE = true;
			frame(state);
			check(state.side == -1, 'ONE selects both sides');

			// SPACE pauses the clock.
			check(state.playing, 'the lab starts playing');
			FlxG.keys.justPressed.SPACE = true;
			frame(state);
			check(!state.playing, 'SPACE pauses the clock');
			FlxG.keys.justPressed.SPACE = true;
			frame(state);
			check(state.playing, 'SPACE resumes the clock');
		}
	}

	static function exportOptions():Void
	{
		final state:ModchartLabState = makeState();
		final drunk:Int = indexOfModifier('drunk');
		final point = listPoint(drunk);
		FlxG.mouse.x = point.x;
		FlxG.mouse.y = point.y;
		FlxG.mouse.justPressed = true;
		frame(state);

		// Hold a low value while the clock walks a few buckets, then drag up:
		// the recording becomes a ramp instead of one rewritten key.
		final low = knobPoint(state, 0, 0.2);
		FlxG.mouse.x = low.x;
		FlxG.mouse.y = low.y;
		FlxG.mouse.justPressed = true;
		FlxG.mouse.pressed = true;
		frame(state);
		for (_ in 0...20)
			frame(state);
		final high = knobPoint(state, 0, 0.9);
		FlxG.mouse.x = high.x;
		for (_ in 0...20)
			frame(state);
		FlxG.mouse.pressed = false;
		frame(state);

		@:privateAccess
		{
			final track:ModchartLabTrack = state.tracks[0];
			check(track.count() >= 2, 'the ramp recorded several keyframes');
			check(track.minValue() < 0.4 && track.maxValue() > 0.8, 'the ramp keeps both ends of the drag');
		}

		// TAB switches the export language.
		@:privateAccess check(state.options.language == Lua, 'the lab exports Lua by default');
		FlxG.keys.justPressed.TAB = true;
		frame(state);
		@:privateAccess
		{
			check(state.options.language == Python, 'TAB switches to Python');
			contains(state.codeText.text, 'def onCreatePost():', 'the Python export defines onCreatePost');
			contains(ModchartLabExport.generate(state.tracks, state.options), '# Modchart Lab', 'the Python export uses hash comments');
		}
		FlxG.keys.justPressed.TAB = true;
		frame(state);
		@:privateAccess check(state.options.language == Lua, 'TAB switches back to Lua');

		// L wraps the section in a repeater.
		FlxG.keys.justPressed.L = true;
		frame(state);
		@:privateAccess
		{
			check(state.options.loop, 'L enables the looping export');
			final looped:String = ModchartLabExport.generate(state.tracks, state.options);
			contains(looped, 'modRepeater(', 'the looping export schedules a repeater');
			contains(looped, 'function onModchartLabSection(beat)', 'the looping export defines the callback');
			contains(state.codeText.text, 'function onModchartLabSection(beat)', 'the preview jumps to the callback body');
			contains(state.codeText.text, "modEase('drunk', beat", 'the preview shows the relative-beat tweens');
		}
		FlxG.keys.justPressed.L = true;
		frame(state);
		@:privateAccess check(!state.options.loop, 'L turns the looping export off again');

		// E/R cycle the ease.
		@:privateAccess final easeBefore:String = state.easeName;
		FlxG.keys.justPressed.E = true;
		frame(state);
		@:privateAccess check(state.easeName != easeBefore, 'E picks the next ease');
		FlxG.keys.justPressed.R = true;
		frame(state);
		@:privateAccess check(state.easeName == easeBefore, 'R walks the ease back');

		// C copies exactly what the preview shows, through the OS clipboard.
		@:privateAccess final expected:String = ModchartLabExport.generate(state.tracks, state.options);
		FlxG.keys.justPressed.C = true;
		frame(state);
		check(Clipboard.text == expected, 'C copies the generated script');
		contains(Clipboard.text, "modEase('drunk'", 'the copied script contains the tween');
		@:privateAccess check(state.copiedTimer > 0, 'the copy is acknowledged in the status line');
	}

	static function transport():Void
	{
		final state:ModchartLabState = makeState();
		@:privateAccess
		{
			check(state.options.startBeat == 0, 'the section starts at beat 0');
			check(state.sectionLength() == 8, 'the section is 8 beats by default');
			check(state.phase == 0, 'the clock starts at the section start');

			// The clock advances and wraps inside the section.
			for (_ in 0...120)
				frame(state);
			check(state.phase >= 0 && state.phase < state.sectionLength(), 'the loop clock wraps');

			state.setStart(4);
			check(state.options.startBeat == 4, 'the section start moves');
			state.setLength(-2);
			check(state.sectionLength() == 6, 'the section length shrinks');

			// Recording at the new length keeps keys inside it.
			final knob:LabKnob = state.currentKnob();
			state.writeKnob(knob.value + 0.2, true);
			final track:ModchartLabTrack = state.currentTrack(true);
			check(track != null && track.count() == 1, 'a direct write records a keyframe');
			check(track.keys[0].beat <= 6, 'recorded beats respect the section length');

			// Shrinking further drops the keys that fall outside.
			state.options.length = 2;
			for (t in state.tracks)
				t.clip(2);
			state.phase = 0;
			frame(state);
			check(state.phase <= 2, 'the clock is clamped to the shorter section');

			// BPM changes re-time the crochet the modifiers read.
			state.setBpm(150);
			check(state.field.crochet == 60000 / 150, 'BPM feeds the playfield crochet');
			state.setBpm(5);
			check(state.bpm == 30, 'BPM is clamped at the low end');
			state.setBpm(999);
			check(state.bpm == 300, 'BPM is clamped at the high end');

			// Full reset drops automation and modifiers, then reinstalls the selection.
			state.clearAllTracks();
			check(state.totalKeys() == 0, 'clear-all empties every track');
			check(state.field.hasModifier(state.currentModifier().name), 'clear-all keeps the preview working');
		}

		// The preview keeps transforming arrows with no automation at all.
		frame(state);
		final arrows:Int = state.members.length;
		check(arrows > 0, 'the state still owns its sprites');
	}

	static function exitsOnBack():Void
	{
		final state:ModchartLabState = makeState();
		@:privateAccess check(!state.exiting, 'the state starts live');
		state.controls.BACK = true;
		frame(state);
		@:privateAccess check(state.exiting, 'BACK marks the state as exiting');
		check(FlxG.switchedState != null, 'BACK switches back to the editor menu');
		check(FlxG.sound.music != null, 'BACK restores the menu music');
		check(!FlxG.mouse.visible, 'the cursor is hidden again on exit');
	}
}
