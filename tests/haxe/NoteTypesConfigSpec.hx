import backend.NoteTypesConfig;
import backend.NoteTypesConfig.NoteTypeProperty;
import backend.Paths;
import objects.Note;

/**
 * Renderer-free contract tests for `backend/NoteTypesConfig.hx` — the parser
 * behind Psych-style `custom_notetypes/<type>.txt` configs that inject
 * properties into chart notes. The module reads through `backend.Paths` and
 * the `sys` filesystem, so the spec runs with the fixture tree under
 * `tests/haxe/fixtures/note-types/` as the working directory (see the runner
 * script). Run with:
 *
 *     bash tests/haxe/run-note-types-config.sh
 */
class NoteTypesConfigSpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts float proximity within 0.001. */
	static function near(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 0.001) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Find the parsed property named `name` (first dot-separated head match). */
	static function findProp(data:Array<NoteTypeProperty>, name:String):Dynamic
	{
		for (entry in data)
			if (entry.property.join('.') == name) return entry.value;
		return 'missing';
	}

	/**
	 * Runs `body` with `haxe.Log.trace` redirected into a buffer. Returns the
	 * captured trace arguments so specs can assert whether the per-entry guard
	 * swallowed anything. The previous trace handler is restored afterwards.
	 */
	static function captureTraces(body:Void->Void):Array<String>
	{
		var captured:Array<String> = [];
		var previous = haxe.Log.trace;
		Reflect.setField(haxe.Log, 'trace', function(value:Dynamic, ?infos:haxe.PosInfos):Void captured.push(Std.string(value)));
		body();
		Reflect.setField(haxe.Log, 'trace', previous);
		return captured;
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		loadsScalars();
		loadsStructure();
		cachesResults();
		missingFilesAreCachedAsNull();
		emptyFileParsesToEmptyList();
		appliesScalarsToNotes();
		appliesExtraDataToNotes();
		dottedNoteTypeLinesAreSkipped();
		bareNoteTypeLinesOverwrite();
		brokenPathsDoNotThrow();
		missingFileApplyIsANoOp();

		Sys.println('NoteTypesConfigSpec: PASS');
	}

	/** Covers loads scalars. */
	static function loadsScalars():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var data = NoteTypesConfig.loadNoteTypeData('Scalars');
		check(data != null, 'Scalars parsed');
		equal(Std.int(findProp(data, 'offsetX')), 12, 'bare integer parses as int');
		near(findProp(data, 'offsetY'), 12.5, 'dotted value parses as float');
		near(findProp(data, 'alpha'), -7, 'negative integer parses');
		equal(findProp(data, 'canMiss'), true, 'true parses as bool');
		equal(findProp(data, 'boolWord'), false, 'false parses as bool');
		equal(findProp(data, 'nothing'), null, 'null parses as null');
		equal(findProp(data, 'quoted'), 'single quoted', 'single-quoted string');
		equal(findProp(data, 'dquoted'), 'double quoted', 'double-quoted string');
		equal(findProp(data, 'weird'), null, 'unrecognized token parses as null');
	}

	/** Covers loads structure. */
	static function loadsStructure():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var data = NoteTypesConfig.loadNoteTypeData('Styled');
		check(data != null, 'Styled parsed');

		// Lines without a separator (and comments) are skipped.
		for (entry in data)
			for (segment in entry.property)
				check(segment.length > 0, 'no empty property segments');

		// Dot-separated property paths keep every segment, trimmed.
		var deep:Dynamic = null;
		var found = false;
		for (entry in data)
			if (entry.property.join('.') == 'extraData.deep')
			{
				deep = entry.value;
				found = true;
			}
		equal(found, true, 'extraData.deep was parsed');
		equal(deep, 'kept', 'dotted path value kept');

		// The extraData special case flattens to the first segment.
		var combo:Dynamic = null;
		for (entry in data)
			if (entry.property.join('.') == 'extraData.combo') combo = entry.value;
		equal(combo, 42, 'extraData.combo parses as int');
	}

	/** Covers caches results. */
	static function cachesResults():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var first = NoteTypesConfig.loadNoteTypeData('Scalars');
		var callsAfterFirstLoad = Paths.getPathCount;
		var second = NoteTypesConfig.loadNoteTypeData('Scalars');
		equal(Paths.getPathCount, callsAfterFirstLoad, 'second load is served from the cache');
		check(first == second, 'cached array identity is preserved');

		NoteTypesConfig.clearNoteTypesData();
		NoteTypesConfig.loadNoteTypeData('Scalars');
		check(Paths.getPathCount == callsAfterFirstLoad + 1, 'clearNoteTypesData forces a re-read');
	}

	/** Covers missing files are cached as null. */
	static function missingFilesAreCachedAsNull():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		equal(NoteTypesConfig.loadNoteTypeData('late-addition'), null, 'missing file loads as null');
		// A file that appears after the failure stays invisible until the
		// cache is cleared: the null result itself is cached.
		sys.io.File.saveContent('custom_notetypes/late-addition.txt', 'offsetX = 1');
		equal(NoteTypesConfig.loadNoteTypeData('late-addition'), null, 'missing-file result is cached');
		NoteTypesConfig.clearNoteTypesData();
		var data = NoteTypesConfig.loadNoteTypeData('late-addition');
		check(data != null, 'cache clear re-reads the file that appeared');
	}

	/** Covers empty file parses to empty list. */
	static function emptyFileParsesToEmptyList():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var data = NoteTypesConfig.loadNoteTypeData('Empty');
		check(data != null, 'empty file is not a load failure');
		equal(data.length, 0, 'empty file parses to an empty property list');
	}

	/** Covers applies scalars to notes. */
	static function appliesScalarsToNotes():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		NoteTypesConfig.applyNoteTypeData(note, 'Styled');
		near(note.offsetX, 3.5, 'offsetX applied');
		near(note.offsetY, -2, 'offsetY applied');
		near(note.alpha, 0.75, 'alpha applied');
		check(note.canMiss, 'canMiss applied');
	}

	/** Covers applies extra data to notes. */
	static function appliesExtraDataToNotes():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		NoteTypesConfig.applyNoteTypeData(note, 'Styled');
		equal(note.extraData.get('combo'), 42, 'extraData.combo set as int');
		equal(note.extraData.get('label'), 'hit', 'extraData.label set as string');
		equal(note.extraData.get('deep'), 'kept', 'extraData values are stored verbatim');
	}

	/**
	 * Dotted `noteType.*` entries are skipped by the loader's special case. The
	 * assertion is not vacuous: without the special case the line would reach
	 * `Reflect.setProperty(String, ...)`, which throws under eval and would be
	 * swallowed into a trace by the per-entry guard — so a silent apply leaves
	 * zero captured traces only when the special case actually skipped the line.
	 */
	static function dottedNoteTypeLinesAreSkipped():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		note.noteType = 'Original';
		var traces = captureTraces(() -> NoteTypesConfig.applyNoteTypeData(note, 'Styled'));
		equal(note.noteType, 'Original', 'dotted noteType.* entries are skipped by the special case');
		equal(traces.length, 0, 'no entry of the Styled fixture threw (dotted line was skipped, not swallowed)');
	}

	/**
	 * Bare `noteType = 'x'` lines (single-segment path) have no special case and
	 * DO overwrite the note's field — the dotted skip only applies to paths.
	 * Pins the current engine behavior so a future tightening of the loader is a
	 * conscious, visible change.
	 */
	static function bareNoteTypeLinesOverwrite():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		note.noteType = 'Original';
		NoteTypesConfig.applyNoteTypeData(note, 'NoteTypeBare');
		equal(note.noteType, 'Clobbered', 'bare noteType lines go through Reflect.setProperty and overwrite');
	}

	/** Covers broken paths do not throw. */
	static function brokenPathsDoNotThrow():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		// 'another.prop.path' cannot resolve on a Note and must be swallowed
		// by the per-entry guard, not take the note down with it.
		var traces = captureTraces(() -> NoteTypesConfig.applyNoteTypeData(note, 'Broken'));
		near(note.offsetX, 1.25, 'valid entries are applied even when a sibling entry is broken');
		equal(traces.length, 1, 'exactly the unresolvable entry reached the per-entry guard');
	}

	/** Covers missing file apply is ano op. */
	static function missingFileApplyIsANoOp():Void
	{
		NoteTypesConfig.clearNoteTypesData();
		Paths.reset();
		var note = new Note();
		note.offsetX = 9;
		NoteTypesConfig.applyNoteTypeData(note, 'missing-under-sys');
		near(note.offsetX, 9, 'applying a missing config changes nothing');
	}
}
