import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import psychlua.StateScripts;
import psychlua.HaxeScript;
import states.ModState;
import states.NestedFixture;
import backend.Mods;
import backend.Paths;
import backend.RuntimeFlags;

/**
 * Renderer-free contract tests for `psychlua/StateScripts.hx` — the overlay
 * that discovers and runs HScript files for every `MusicBeatState` /
 * `MusicBeatSubstate` (`data/states/<StateName>.hx`) and the blank hosts
 * (`ModState` / `ModSubState`). Covers the path sanitizer (the traversal
 * guard), script discovery across the game and mod folders, the call merge
 * semantics and teardown. Runs with the current working directory writable;
 * the fixture tree is built under `fix/` and the runner discards it after
 * the run. Run with:
 *
 *     bash tests/haxe/run-state-scripts.sh
 */
class StateScriptsSpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Creates a directory (recursively), ignoring the already-exists case. */
	static function mkdirp(path:String):Void
	{
		var parts = path.split('/');
		var cur = '';
		for (part in parts)
		{
			if (part.length == 0) continue;
			cur = cur.length == 0 ? part : cur + '/' + part;
			if (!FileSystem.exists(cur)) FileSystem.createDirectory(cur);
		}
	}

	/** Writes a fixture file, creating parent directories as needed. */
	static function writeFixture(path:String, content:String):Void
	{
		var slash = path.lastIndexOf('/');
		mkdirp(path.substr(0, slash));
		File.saveContent(path, content);
	}

	/** Restores the sandboxed filesystem env vars so tests are order-independent. */
	static function resetEnvironment():Void
	{
		Paths.root = 'fix/';
		Mods.reset();
		RuntimeFlags.reset();
		HaxeScript.reset();
	}

	/** Build the fixture tree the discovery tests share. */
	static function buildFixtureTree():Void
	{
		writeFixture('fix/game/data/states/TestState.hx', '// game TestState');
		writeFixture('fix/game/data/states/TestState.hscript', '// game TestState hscript');
		writeFixture('fix/game/data/states/OnlyHx.hx', '// game OnlyHx');
		writeFixture('fix/game/data/states/OnlyHscript.hscript', '// game OnlyHscript');
		writeFixture('fix/mods/mymod/data/states/TestState.hscript', '// mymod TestState');
		writeFixture('fix/mods/othermod/data/states/TestState.hx', '// othermod TestState');
		writeFixture('fix/mods/data/states/TestState.hxs', '// global TestState');
		writeFixture('fix/mods/curmod/data/states/TestState.hx', '// curmod TestState');
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		sanitizeName();
		classScriptNameAndResolve();
		collectFiles();
		collectFilesDeduplicatesModFolders();
		loadCreatesScriptsAndSkipsClosed();
		loadAlsoLoadsTheDefaultStateFlag();
		callMergeSemantics();
		setAndDestroy();
		switchStateSemantics();
		openSubStateSemantics();
		readFile();

		Sys.println('StateScriptsSpec: PASS');
	}

	/** Covers sanitize name. */
	static function sanitizeName():Void
	{
		equal(StateScripts.sanitizeName('FreeplayState'), 'FreeplayState', 'plain name passes through');
		equal(StateScripts.sanitizeName('week6/states/TestState'), 'week6/states/TestState', 'nested path passes through');
		equal(StateScripts.sanitizeName('..\\evil'), '', 'backslashes are normalized, then rejected');
		equal(StateScripts.sanitizeName('../evil'), '', 'parent traversal is rejected');
		equal(StateScripts.sanitizeName('a/../../b'), '', 'embedded parent traversal is rejected');
		equal(StateScripts.sanitizeName('..'), '', 'bare parent segment is rejected');
		equal(StateScripts.sanitizeName('C:/windows/system32'), '', 'drive letters are rejected');
		equal(StateScripts.sanitizeName('C:'), '', 'bare drive letter is rejected');
		equal(StateScripts.sanitizeName('a//b'), 'a/b', 'empty segments collapse');
		equal(StateScripts.sanitizeName('a/./b'), 'a/b', 'single-dot segments collapse');
		equal(StateScripts.sanitizeName('/leading/slash'), 'leading/slash', 'leading slashes are stripped');
		equal(StateScripts.sanitizeName('a\\b\\c'), 'a/b/c', 'backslashes become slashes');
		equal(StateScripts.sanitizeName(' padded / name '), 'padded/name', 'segments are trimmed');
		equal(StateScripts.sanitizeName(''), '', 'empty string stays empty');
		equal(StateScripts.sanitizeName(null), '', 'null becomes empty');
		equal(StateScripts.sanitizeName('.'), '', 'bare single dot becomes empty');
		// Dotfiles are not traversal and must survive.
		equal(StateScripts.sanitizeName('.hidden'), '.hidden', 'dotfiles pass through');
	}

	/** Covers class script name and resolve. */
	static function classScriptNameAndResolve():Void
	{
		equal(StateScripts.classScriptName(null), '', 'null instance has no script name');
		equal(StateScripts.classScriptName(new StateScriptsSpecFixture()), 'StateScriptsSpecFixture', 'unqualified class name');
		equal(StateScripts.classScriptName(new NestedFixture()), 'NestedFixture', 'package prefix is stripped');

		equal(StateScripts.resolveName(new StateScriptsSpecFixture(), null), 'StateScriptsSpecFixture', 'instance name is used without an override');
		equal(StateScripts.resolveName(new StateScriptsSpecFixture(), 'Custom Name'), 'Custom Name', 'override wins over the class name');
		equal(StateScripts.resolveName(new StateScriptsSpecFixture(), ''), 'StateScriptsSpecFixture', 'empty override falls back to the class name');
		equal(StateScripts.resolveName(new StateScriptsSpecFixture(), '../escape'), '', 'a hostile override is sanitized');
		equal(StateScripts.resolveName(null, 'Override'), 'Override', 'override works without an instance');
		equal(StateScripts.resolveName(null, null), '', 'no instance and no override gives nothing');
	}

	/** Covers collect files. */
	static function collectFiles():Void
	{
		resetEnvironment();
		buildFixtureTree();
		Mods.globalMods = ['mymod', 'othermod'];
		Mods.currentModDirectory = 'curmod';

		var files = StateScripts.collectFiles('TestState');
		equal(files.length, 6, 'all six TestState scripts across every folder');
		equal(files[0], 'fix/game/data/states/TestState.hx', 'game hx first');
		equal(files[1], 'fix/game/data/states/TestState.hscript', 'game hscript second');
		equal(files[2], 'fix/mods/mymod/data/states/TestState.hscript', 'global mods come before the fallback folder');
		equal(files[3], 'fix/mods/othermod/data/states/TestState.hx', 'later global mods keep their order');
		equal(files[4], 'fix/mods/data/states/TestState.hxs', 'the plain mods folder comes after global mods');
		equal(files[5], 'fix/mods/curmod/data/states/TestState.hx', 'the current mod directory comes last');

		// Extension priority is hx, hscript, hxs within each folder.
		var onlyHx = StateScripts.collectFiles('OnlyHx');
		equal(onlyHx.length, 1, 'only hx found for OnlyHx');
		equal(onlyHx[0], 'fix/game/data/states/OnlyHx.hx', 'OnlyHx resolves to the game file');
		var onlyHscript = StateScripts.collectFiles('OnlyHscript');
		equal(onlyHscript.length, 1, 'only hscript found for OnlyHscript');

		// Discovery of unknown and hostile names yields nothing.
		equal(StateScripts.collectFiles('NoSuchState').length, 0, 'unknown name discovers nothing');
		equal(StateScripts.collectFiles('../outside').length, 0, 'traversal discovers nothing');
		equal(StateScripts.collectFiles('').length, 0, 'empty name discovers nothing');

		check(StateScripts.exists('TestState'), 'exists is true for a discoverable name');
		check(!StateScripts.exists('NoSuchState'), 'exists is false for an unknown name');
	}

	/** Covers collect files deduplicates mod folders. */
	static function collectFilesDeduplicatesModFolders():Void
	{
		resetEnvironment();
		buildFixtureTree();
		// The current mod directory is also a global mod: its folder appears
		// twice in the search path, and every path must come back only once.
		Mods.globalMods = ['mymod'];
		Mods.currentModDirectory = 'mymod';

		var files = StateScripts.collectFiles('TestState');
		equal(files.length, 4, 'the duplicated mod folder contributes no duplicate files');
		equal(files[0], 'fix/game/data/states/TestState.hx', 'game hx first');
		equal(files[1], 'fix/game/data/states/TestState.hscript', 'game hscript second');
		equal(files[2], 'fix/mods/mymod/data/states/TestState.hscript', 'the mod hscript comes third');
		equal(files[3], 'fix/mods/data/states/TestState.hxs', 'the plain mods folder hscript comes last, once');
	}

	/** Covers load creates scripts and skips closed. */
	static function loadCreatesScriptsAndSkipsClosed():Void
	{
		resetEnvironment();
		buildFixtureTree();
		Mods.globalMods = ['mymod', 'othermod'];
		Mods.currentModDirectory = 'curmod';
		HaxeScript.closeOnCreate = ['fix/mods/othermod/data/states/TestState.hx'];

		var parent = new StateScriptsSpecFixture();
		var pack = StateScripts.loadFor(parent, 'TestState');
		equal(pack.scriptName, 'TestState', 'scriptName is the sanitized name');
		equal(pack.scripts.length, 5, 'the closed script is not added to the pack');
		equal(pack.scripts[0].path, 'fix/game/data/states/TestState.hx', 'scripts keep discovery order');
		equal(pack.parent, parent, 'the parent is carried on the pack');
		check(pack.hasScripts(), 'hasScripts is true when scripts were loaded');
		check(!pack.scripts[0].closed, 'loaded scripts are not closed');
		for (script in pack.scripts)
			equal(script.parent, parent, 'every script gets the parent instance');

		// A pack with no discoverable scripts has nothing to run.
		var empty = StateScripts.loadFor(parent, 'NoSuchState');
		equal(empty.scripts.length, 0, 'unknown names load no scripts');
		check(!empty.hasScripts(), 'hasScripts is false with no scripts');
	}

	/** Covers load also loads the default state flag. */
	static function loadAlsoLoadsTheDefaultStateFlag():Void
	{
		resetEnvironment();
		buildFixtureTree();
		RuntimeFlags.strings['scripts.defaultState'] = 'OnlyHx';

		var parent = new StateScriptsSpecFixture();
		var pack = StateScripts.loadFor(parent, 'TestState');
		var paths:Array<String> = [for (script in pack.scripts) script.path];
		check(paths.indexOf('fix/game/data/states/TestState.hx') >= 0, 'the named script set loads');
		check(paths.indexOf('fix/game/data/states/OnlyHx.hx') >= 0, 'the scripts.defaultState flag adds its file too');
		// The default state may not exist, may be sanitized away, and may
		// duplicate the named set: none of those may blow up.
		RuntimeFlags.strings['scripts.defaultState'] = '../escape';
		var hostile = StateScripts.loadFor(parent, 'TestState');
		check(hostile.scripts.length >= 0, 'a hostile default state flag does not throw');

		RuntimeFlags.strings['scripts.defaultState'] = 'TestState';
		var dup = StateScripts.loadFor(parent, 'TestState');
		var count = 0;
		for (script in dup.scripts)
			if (script.path == 'fix/game/data/states/TestState.hx') count++;
		equal(count, 1, 'the default state is not loaded twice when it matches the named one');
	}

	/** Covers call merge semantics. */
	static function callMergeSemantics():Void
	{
		resetEnvironment();
		var pack = new StateScripts(null, 'test');
		var a = new HaxeScript('a.hx', null);
		var b = new HaxeScript('b.hx', null);

		HaxeScript.responses = new Map();
		pack.scripts = [a, b];

		// All continue: the call reports continue.
		pack.call('onFoo');
		equal(pack.call('onFoo'), StateScripts.Function_Continue, 'all-continue merges to continue');

		// One stops: stop wins regardless of position.
		HaxeScript.responses = new Map();
		HaxeScript.responses.set('a.hx|onFoo', [StateScripts.Function_Stop]);
		HaxeScript.responses.set('b.hx|onFoo', [StateScripts.Function_Continue]);
		equal(pack.call('onFoo'), StateScripts.Function_Stop, 'stop wins from the first script');

		HaxeScript.responses = new Map();
		HaxeScript.responses.set('a.hx|onFoo', [StateScripts.Function_Continue]);
		HaxeScript.responses.set('b.hx|onFoo', [StateScripts.Function_Stop]);
		equal(pack.call('onFoo'), StateScripts.Function_Stop, 'stop wins from the last script');

		// Non-null, non-continue values override; the latest one wins.
		HaxeScript.responses = new Map();
		HaxeScript.responses.set('a.hx|onFoo', ['first']);
		HaxeScript.responses.set('b.hx|onFoo', ['second']);
		equal(pack.call('onFoo'), 'second', 'the latest non-continue value wins');

		HaxeScript.responses = new Map();
		HaxeScript.responses.set('a.hx|onFoo', [null]);
		HaxeScript.responses.set('b.hx|onFoo', ['kept']);
		equal(pack.call('onFoo'), 'kept', 'null returns do not override');

		// Arguments are forwarded to every script in order.
		pack.call('onArgs', [1, 'two']);
		equal(a.calls.length + b.calls.length > 0, true, 'arguments reach the scripts');
		var sawArgs = false;
		for (entry in a.calls)
			if (entry.name == 'onArgs' && entry.args[0] == 1 && entry.args[1] == 'two') sawArgs = true;
		check(sawArgs, 'the first script received the exact arguments');

		// Empty pack: continue, and no crash.
		var empty = new StateScripts(null, 'empty');
		equal(empty.call('onFoo'), StateScripts.Function_Continue, 'empty pack reports continue');
		equal(empty.call(null), StateScripts.Function_Continue, 'a null method name reports continue');

		// Stop values propagate even when a custom value came before.
		HaxeScript.responses = new Map();
		HaxeScript.responses.set('a.hx|onFoo', ['custom']);
		HaxeScript.responses.set('b.hx|onFoo', [StateScripts.Function_Stop]);
		equal(pack.call('onFoo'), StateScripts.Function_Stop, 'stop beats an earlier custom value');
	}

	/** Covers set and destroy. */
	static function setAndDestroy():Void
	{
		resetEnvironment();
		var pack = new StateScripts(null, 'test');
		var a = new HaxeScript('a.hx', null);
		var b = new HaxeScript('b.hx', null);
		pack.scripts = [a, b];

		pack.set('someValue', 42);
		equal(a.sets.get('someValue'), 42, 'set reaches the first script');
		equal(b.sets.get('someValue'), 42, 'set reaches the last script');

		pack.destroy();
		check(a.stopped, 'destroy stops the first script');
		check(b.stopped, 'destroy stops the last script');
		equal(pack.scripts.length, 0, 'destroy empties the script list');
		equal(pack.parent, null, 'destroy drops the parent reference');
	}

	/** Covers read file. */
	static function readFile():Void
	{
		resetEnvironment();
		writeFixture('fix/readable.txt', 'hello scripts');
		equal(StateScripts.readFile('fix/readable.txt'), 'hello scripts', 'readFile returns file contents');
		equal(StateScripts.readFile('fix/does-not-exist.txt'), null, 'readFile of a missing file returns null');
		equal(StateScripts.readFile(''), null, 'readFile of an empty path returns null');
		equal(StateScripts.readFile(null), null, 'readFile of null returns null');
	}

	/** Covers switch state semantics. */
	static function switchStateSemantics():Void
	{
		resetEnvironment();
		FlxG.reset();
		FlxTransitionableState.reset();
		ModState.reset();

		// A hostile name never reaches the state machine.
		equal(StateScripts.switchState('../escape'), false, 'hostile name is rejected');
		check(!FlxG.switchStateCalled, 'a rejected name never reaches FlxG');

		// A valid name, transition skipped: the flags are set, the switch is
		// queued, and the factory builds a ModState with the sanitized name.
		var payload:Dynamic = {level: 'hard'};
		equal(StateScripts.switchState('SomeState', payload, true), true, 'valid name switches');
		check(FlxG.switchStateCalled, 'FlxG.switchState was called');
		check(FlxTransitionableState.skipNextTransIn, 'skipTransition sets skipNextTransIn');
		check(FlxTransitionableState.skipNextTransOut, 'skipTransition sets skipNextTransOut');
		check(FlxG.nextStateFactory != null, 'the factory was captured');

		var made:Dynamic = FlxG.nextStateFactory();
		equal(made.name, 'SomeState', 'the factory builds a ModState with the sanitized name');
		equal(made.data, payload, 'the factory forwards the payload');
		equal(ModState.created.length, 1, 'exactly one ModState was created');
		equal(ModState.created[0].name, 'SomeState', 'created state records the name');
	}

	/** Covers open sub state semantics. */
	static function openSubStateSemantics():Void
	{
		resetEnvironment();
		FlxG.reset();

		// A hostile name is rejected before FlxG is touched.
		equal(StateScripts.openSubState('../escape'), false, 'hostile name is rejected');
		// A valid name with no current state is rejected too.
		equal(StateScripts.openSubState('SomeSub'), false, 'no current state means no overlay');

		// With a state present, the substate overlay opens on it.
		var opened:Array<Dynamic> = [];
		FlxG.state = {openSubState: function(sub:Dynamic):Void opened.push(sub)};
		equal(StateScripts.openSubState('Some Sub', {x: 1}), true, 'valid name opens the overlay');
		equal(opened.length, 1, 'openSubState was called on the current state');
		equal(opened[0].name, 'Some Sub', 'the substate carries the sanitized name');
		equal(opened[0].data.x, 1, 'the payload is forwarded');

		FlxG.reset();
	}

}

/** Plain fixture class for the class-name reflection tests. */
class StateScriptsSpecFixture
{
	public function new() {}
}
