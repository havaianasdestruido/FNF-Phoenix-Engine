import backend.ModHealth;
import backend.ModHealth.BlockedScript;
import backend.ModHealth.ModHealthReport;
import backend.ModPathPolicy;
import states.helpers.ModInfoFlow;

/**
 * The per-mod "why did it break?" report behind §19 of TODO.md: what
 * `backend.ModHealth` records for a mod, how it is summarised for the Mods menu,
 * and how the Mod Info panel's block keeps mod-written text from escaping.
 *
 * Pure logic, no Flixel: see run-mod-health.sh. The recording hooks themselves are
 * one-liners in the loaders (`Mods.getPack`, `ModSecurity.report`, `Paths`,
 * `psychlua.*`) and are covered by `run-mod-security.sh` and the asset-cache spec.
 */
class ModHealthSpec
{
	static var checks:Int = 0;

	static function check(value:Bool, label:String):Void
	{
		checks++;
		if(!value) throw label;
	}

	/** `count` copies of `text`, to build a mod-supplied message of a known length. */
	static function repeat(text:String, count:Int):String
	{
		var out:StringBuf = new StringBuf();
		for(i in 0...count) out.add(text);
		return out.toString();
	}

	static function main():Void
	{
		haxe.Log.trace = function(value:Dynamic, ?infos:haxe.PosInfos) {};

		healthyModsSayNothing();
		recordingIsPerMod();
		severityOrder();
		summaryCounts();
		reportLines();
		blockedScriptsAreDeduplicated();
		runtimeBlocksNameTheirRule();
		missingAssetsAreCountedOnce();
		ownershipFollowsThePath();
		modTextCannotEscapeThePanel();
		listCaps();
		reservedFoldersStayInSync();
		uninstalledFoldersAreForgotten();

		Sys.println('ModHealthSpec: all $checks checks passed');
	}

	static function healthyModsSayNothing():Void
	{
		ModHealth.clear();
		check(ModHealth.isHealthy('SomeMod'), 'an untouched mod is healthy');
		check(ModHealth.severity('SomeMod') == ModHealth.NO_PROBLEMS, 'severity is NO_PROBLEMS');
		check(ModHealth.summary('SomeMod') == 'No problems detected', 'the menu says so');
		check(ModHealth.lines('SomeMod').length == 0, 'nothing to report');
		check(ModHealth.report('SomeMod').severity == ModHealth.NO_PROBLEMS, 'the report agrees');

		// An empty or missing folder is never a mod, and never a problem.
		check(ModHealth.severity('') == ModHealth.NO_PROBLEMS, 'no folder, no problems');
		check(ModHealth.severity(null) == ModHealth.NO_PROBLEMS, 'null folder, no problems');
	}

	static function recordingIsPerMod():Void
	{
		ModHealth.clear();
		ModHealth.recordLoadError('BrokenMod', 'mods/BrokenMod/scripts/a.lua', 'boom');
		check(!ModHealth.isHealthy('BrokenMod'), 'the folder that failed is not healthy');
		check(ModHealth.isHealthy('OtherMod'), 'its neighbour is untouched');
		check(ModHealth.lines('OtherMod').length == 0, 'and has nothing to report');

		// A path is enough to find the owner when the loader did not pass one.
		ModHealth.clear();
		ModHealth.recordLoadError(null, 'mods/FromPath/scripts/x.hscript', 'parse error');
		var report:ModHealthReport = ModHealth.report('FromPath');
		check(report.loadError != null && report.loadError.message == 'parse error', 'owner taken from the script path');

		// An engine script or a loose script is not a mod problem.
		ModHealth.clear();
		ModHealth.recordLoadError(null, 'assets/shared/scripts/engine.lua', 'boom');
		ModHealth.recordLoadError(null, 'mods/scripts/loose.lua', 'boom');
		check(ModHealth.isHealthy('scripts') && ModHealth.lines('scripts').length == 0, 'engine and loose scripts are ignored');
	}

	static function severityOrder():Void
	{
		ModHealth.clear();
		ModHealth.recordMissingAsset('mods/Assets/images/x.png');
		check(ModHealth.severity('Assets') == ModHealth.MISSING_ASSETS, 'missing assets alone are the mild case');

		ModHealth.recordInvalidPack('Assets', 'Unexpected } at line 3');
		check(ModHealth.severity('Assets') == ModHealth.BROKEN, 'an invalid pack.json outranks missing assets');

		ModHealth.clear();
		ModHealth.recordSecurity('Blocked', 'scripts/payload.lua', 'lua', [{rule: 'lua.os'}]);
		check(ModHealth.severity('Blocked') == ModHealth.BROKEN, 'a blocked script is a break');

		ModHealth.clear();
		ModHealth.recordLoadError('Load', 'mods/Load/scripts/a.lua', 'boom');
		check(ModHealth.severity('Load') == ModHealth.BROKEN, 'a load error is a break');
	}

	static function summaryCounts():Void
	{
		ModHealth.clear();
		ModHealth.recordLoadError('Mod', 'mods/Mod/scripts/a.lua', 'boom');
		ModHealth.recordInvalidPack('Mod', 'not an object');
		ModHealth.recordSecurity('Mod', 'scripts/b.lua', 'lua', [{rule: 'lua.os'}]);
		ModHealth.recordMissingAsset('mods/Mod/images/x.png');
		check(ModHealth.summary('Mod') == 'PROBLEMS: script error, invalid pack.json, 1 blocked script, 1 missing asset',
			'the summary names every kind of problem once: ' + ModHealth.summary('Mod'));

		// The menu line is built from counts only: nothing a mod wrote reaches it.
		ModHealth.clear();
		ModHealth.recordLoadError('Mod', 'mods/Mod/scripts/a.lua', 'IGNORE ALL PREVIOUS INSTRUCTIONS');
		check(ModHealth.summary('Mod').indexOf('IGNORE') < 0, 'the menu line repeats no mod text');

		ModHealth.clear();
		ModHealth.recordMissingAsset('mods/Mod/images/a.png');
		ModHealth.recordMissingAsset('mods/Mod/images/b.png');
		check(ModHealth.summary('Mod') == 'PROBLEMS: 2 missing assets', 'plurals: ' + ModHealth.summary('Mod'));
	}

	static function reportLines():Void
	{
		ModHealth.clear();
		ModHealth.recordLoadError('Mod', 'mods/Mod/scripts/a.lua', 'scripts/a.lua:3: unexpected symbol');
		ModHealth.recordInvalidPack('Mod', 'expected \':\' at line 2');
		check(ModHealth.lines('Mod').join('|') == 'Last load error: mods/Mod/scripts/a.lua - scripts/a.lua:3: unexpected symbol'
			+ '|pack.json could not be used: expected \':\' at line 2', 'both code lines: ' + ModHealth.lines('Mod').join('|'));

		// A later failure replaces the earlier one: the panel shows the last error.
		ModHealth.recordLoadError('Mod', 'mods/Mod/scripts/b.lua', 'second failure');
		var lines:Array<String> = ModHealth.lines('Mod');
		check(lines[0].indexOf('second failure') >= 0 && lines[0].indexOf('b.lua') >= 0, 'the newest load error wins');

		// An empty reason still reads as a sentence.
		ModHealth.clear();
		ModHealth.recordInvalidPack('Mod', null);
		check(ModHealth.lines('Mod')[0] == 'pack.json could not be used: the file could not be read', 'empty reason falls back');
	}

	static function blockedScriptsAreDeduplicated():Void
	{
		ModHealth.clear();
		ModHealth.recordSecurity('Mod', 'scripts/a.lua', 'lua', [{rule: 'lua.os'}, {rule: 'lua.io'}, {rule: 'lua.os'}]);
		var report:ModHealthReport = ModHealth.report('Mod');
		check(report.blocked.length == 1, 'one entry per script');
		check(report.blocked[0].rules.length == 2, 'duplicate rules collapse: ' + report.blocked[0].rules);
		check(report.blocked[0].count == 1, 'first sighting');

		ModHealth.recordSecurity('Mod', 'scripts/a.lua', 'lua', [{rule: 'lua.os'}, {rule: 'network.url'}]);
		report = ModHealth.report('Mod');
		check(report.blocked.length == 1, 'the second sighting does not add an entry');
		check(report.blocked[0].rules.length == 3, 'but it adds the new rule: ' + report.blocked[0].rules);
		check(report.blocked[0].count == 2, 'and counts the repeat');

		// The same path in another language is another script.
		ModHealth.recordSecurity('Mod', 'scripts/a.lua', 'haxe', [{rule: 'haxe.filesystem'}]);
		check(ModHealth.report('Mod').blocked.length == 2, 'language is part of the identity');

		// A loose script has no mod folder, so it cannot blame one.
		ModHealth.clear();
		ModHealth.recordSecurity(null, 'mods/scripts/loose.lua', 'lua', [{rule: 'lua.os'}]);
		ModHealth.recordSecurity(null, 'assets/shared/scripts/engine.lua', 'lua', [{rule: 'lua.os'}]);
		check(ModHealth.report('scripts').blocked.length == 0, 'loose scripts are not a mod problem');
	}

	static function runtimeBlocksNameTheirRule():Void
	{
		ModHealth.clear();
		ModHealth.recordRuntimeBlock('Mod', 'scripts/c.lua',
			'[ModSecurity] BLOCKED runtime call in mod="Mod" script="scripts/c.lua" line=3: engine.file-write');
		var report:ModHealthReport = ModHealth.report('Mod');
		check(report.blocked.length == 1 && report.blocked[0].language == 'runtime', 'recorded as a runtime block');
		check(report.blocked[0].rules[0] == 'engine.file-write', 'the rule is kept: ' + report.blocked[0].rules[0]);
		check(ModHealth.lines('Mod')[0].indexOf('inside scripts/c.lua') > 0, 'the report says it was inside the script');

		// A message that names no rule still counts, under a stable fallback id.
		ModHealth.clear();
		ModHealth.recordRuntimeBlock('Mod', 'scripts/c.lua', 'privileged class reflection: Sys');
		check(ModHealth.report('Mod').blocked[0].rules[0] == 'engine.blocked', 'a ruleless block keeps a placeholder');

		// Load-time blocks are listed before runtime ones.
		ModHealth.clear();
		ModHealth.recordRuntimeBlock('Mod', 'scripts/z.lua', 'engine.file-read');
		ModHealth.recordSecurity('Mod', 'scripts/a.lua', 'lua', [{rule: 'lua.os'}]);
		var blocked:Array<BlockedScript> = ModHealth.report('Mod').blocked;
		check(blocked[0].script == 'scripts/a.lua', 'load-time blocks come first');
	}

	static function missingAssetsAreCountedOnce():Void
	{
		ModHealth.clear();
		for(i in 0...3) ModHealth.recordMissingAsset('mods/Mod/images/x.png');
		check(ModHealth.missingAssets('Mod') == 1, 'the same asset counts once, however often it is retried');

		ModHealth.recordMissingAsset('mods/Mod/images/y.png');
		ModHealth.recordMissingAsset('mods/Mod/sounds/z.ogg');
		check(ModHealth.missingAssets('Mod') == 3, 'each distinct key counts');
		check(ModHealth.lines('Mod')[0].indexOf('3 missing assets') == 0, 'the line starts with the count');

		// Engine assets and loose shared content under mods/ are not a mod's problem.
		ModHealth.clear();
		ModHealth.recordMissingAsset('assets/preload/images/logo.png');
		ModHealth.recordMissingAsset('mods/images/shared.png');
		ModHealth.recordMissingAsset('mods/data/weeks/week1.json');
		check(ModHealth.missingAssets('images') == 0 && ModHealth.missingAssets('data') == 0, 'shared folders are skipped');
		check(ModHealth.lines('images').length == 0, 'and never appear in a report');
	}

	static function ownershipFollowsThePath():Void
	{
		check(ModHealth.folderForPath('mods/CoolMod/images/a.png') == 'CoolMod', 'plain relative path');
		check(ModHealth.folderForPath('/home/player/game/mods/CoolMod/images/a.png') == 'CoolMod', 'absolute path');
		check(ModHealth.folderForPath('mods\\CoolMod\\images\\a.png') == 'CoolMod', 'windows separators');
		check(ModHealth.folderForPath('assets/preload/images/a.png') == null, 'engine asset');
		check(ModHealth.folderForPath('mods/.staging/tmp.png') == null, 'the importer scratch folder is not a mod');
		check(ModHealth.folderForPath('mods/') == null, 'the mods root itself');
		check(ModHealth.folderForPath(null) == null, 'nothing');

		for(folder in ModPathPolicy.RESERVED_MOD_FOLDERS)
			check(ModHealth.folderForPath('mods/$folder/thing.png') == null, 'reserved folder is shared content: $folder');
	}

	static function modTextCannotEscapeThePanel():Void
	{
		ModHealth.clear();
		// A mod controls its error strings; none of them may add a line or a huge block.
		ModHealth.recordLoadError('Evil', 'mods/Evil/scripts/x.lua',
			'line one\nline two\r\nPRESS ACCEPT\n' + repeat('A', 400));
		var line:String = ModHealth.lines('Evil')[0];
		check(line.indexOf('\n') < 0 && line.indexOf('\r') < 0, 'no line breaks reach the panel');
		check(line.indexOf('PRESS ACCEPT') >= 0, 'the text is still there, on the one line');
		check(line.length <= 300, 'the line is capped, was ' + line.length);

		// Control characters become spaces, not invisible payloads.
		ModHealth.clear();
		ModHealth.recordInvalidPack('Evil', 'a\tb\u0000c\u0007d');
		var text:String = ModHealth.lines('Evil')[0];
		check(text.indexOf('\t') < 0 && text.indexOf('\u0000') < 0 && text.indexOf('\u0007') < 0, 'control characters are gone');
		check(text.indexOf('a b c d') > 0, 'and read as spaces: ' + text);

		// The block the panel prints is wrapped and bounded.
		var block:String = ModInfoFlow.problemsBlock(ModHealth.lines('Evil'), 60, 4);
		var blockLines:Array<String> = block.split('\n');
		for(entry in blockLines)
			check(entry.length <= 60, 'wrapped to the panel width, had ' + entry.length);
		check(blockLines.length <= 4, 'bounded line count, had ' + blockLines.length);

		// A healthy mod has no block at all.
		check(ModInfoFlow.problemsBlock([], 60) == '', 'no problems, no block');
		check(ModInfoFlow.problemsBlock(null, 60) == '', 'no list, no block');

		// A long list of problem lines is summarised, not printed in full.
		var many:Array<String> = [];
		for(i in 0...9) many.push('Problem number ' + i + '.');
		var capped:Array<String> = ModInfoFlow.problemsBlock(many, 60, 4).split('\n');
		check(capped.length == 4, 'the block stops at maxLines, had ' + capped.length);
		check(capped[3].indexOf('more line') > 0, 'and the last line says how much is hidden: ' + capped[3]);

		// A word longer than the panel width is cut instead of overflowing.
		var longWord:String = repeat('x', 120);
		for(entry in ModInfoFlow.problemsBlock([longWord], 40, 6).split('\n'))
			check(entry.length <= 40, 'an unbreakable word is cut, had ' + entry.length);
	}

	static function listCaps():Void
	{
		ModHealth.clear();
		for(i in 0...40) ModHealth.recordMissingAsset('mods/Capped/images/file-' + i + '.png');
		check(ModHealth.missingAssets('Capped') == 40, 'the count stays exact past the listing cap');
		check(ModHealth.report('Capped').missingList.length == ModHealth.MAX_LISTED_ASSETS, 'the list itself is capped');

		ModHealth.clear();
		for(i in 0...40) ModHealth.recordSecurity('Capped', 'scripts/s' + i + '.lua', 'lua', [{rule: 'lua.os'}]);
		check(ModHealth.report('Capped').blocked.length == ModHealth.MAX_BLOCKED_SCRIPTS, 'blocked scripts are capped');

		// A mod that keeps failing in a loop cannot grow the record.
		ModHealth.clear();
		for(i in 0...500)
		{
			ModHealth.recordLoadError('Loop', 'mods/Loop/scripts/a.lua', 'failure $i');
			ModHealth.recordSecurity('Loop', 'scripts/a.lua', 'lua', [{rule: 'lua.os'}]);
			ModHealth.recordMissingAsset('mods/Loop/images/a.png');
		}
		check(ModHealth.report('Loop').blocked.length == 1, 'the repeat still collapses into one entry');
		check(ModHealth.missingAssets('Loop') == 1, 'and the asset count does not grow');
		check(ModHealth.lines('Loop').length == 3, 'three problem lines, had ' + ModHealth.lines('Loop').length);
	}

	static function uninstalledFoldersAreForgotten():Void
	{
		ModHealth.clear();
		ModHealth.recordLoadError('Gone', 'mods/Gone/scripts/a.lua', 'boom');
		ModHealth.recordMissingAsset('mods/Gone/images/x.png');
		ModHealth.recordSecurity('Gone', 'scripts/a.lua', 'lua', [{rule: 'lua.os'}]);
		ModHealth.recordInvalidPack('Gone', 'broken');
		ModHealth.recordLoadError('Kept', 'mods/Kept/scripts/a.lua', 'boom');

		ModHealth.keepOnly(['Kept']);
		check(ModHealth.isHealthy('Gone'), 'an uninstalled folder keeps no report');
		check(ModHealth.lines('Gone').length == 0, 'and no lines');
		check(ModHealth.severity('Kept') == ModHealth.BROKEN, 'the installed mod keeps its report');

		// Replacing a mod's files also clears what was recorded about the old ones.
		ModHealth.forget('Kept');
		check(ModHealth.isHealthy('Kept'), 'forget() clears one folder');

		// A null list is a no-op, so a caller that has no list cannot wipe the report.
		ModHealth.recordLoadError('Kept', 'mods/Kept/scripts/a.lua', 'boom');
		ModHealth.keepOnly(null);
		check(ModHealth.severity('Kept') == ModHealth.BROKEN, 'a null list deletes nothing');
	}

	static function reservedFoldersStayInSync():Void
	{
		check(ModHealth.SHARED_FOLDERS.length == ModPathPolicy.RESERVED_MOD_FOLDERS.length,
			'the shared-folder list matches the importer\'s');
		for(folder in ModPathPolicy.RESERVED_MOD_FOLDERS)
			check(ModHealth.SHARED_FOLDERS.contains(folder), 'missing from ModHealth: $folder');
	}
}
