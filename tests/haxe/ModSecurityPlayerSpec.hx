import backend.ModSecurity;
import backend.ModSecurity.ModSecurityCheck;
import backend.Mods;
import sys.FileSystem;
import sys.io.File;

/**
 * The per-mod ModSecurity switch of the Mods menu (Mod Info): how the player's
 * choice combines with a mod's pack.json, how it is kept in modSecurity.txt and
 * what the log says about it.
 *
 * Built with -D MODS_ALLOWED against a stub `backend.Mods` (this spec hands it
 * the pack.json objects) and run inside a throwaway working directory, because
 * modSecurity.txt is read and written relative to it. See run-mod-security.sh.
 */
class ModSecurityPlayerSpec
{
	static inline final FILE:String = ModSecurity.PLAYER_OVERRIDES_FILE;
	static inline final UNSAFE_LUA:String = "os.execute('bad')";

	static var checks:Int = 0;

	static function check(value:Bool, label:String):Void
	{
		checks++;
		if(!value) throw label;
	}

	/** A script that the scanner blocks whenever the owning mod is sandboxed. */
	static function lua(folder:String):ModSecurityCheck
		return ModSecurity.checkScript('mods/$folder/scripts/payload.lua', UNSAFE_LUA, 'lua');

	static function blocked(decision:ModSecurityCheck):Bool
		return decision.sandboxed && !decision.optedOut && decision.findings.length == 1 && decision.findings[0].rule == 'lua.os';

	static function unrestricted(decision:ModSecurityCheck):Bool
		return !decision.sandboxed && decision.optedOut && decision.findings.length == 0;

	static function fileText():Null<String>
		return FileSystem.exists(FILE) ? File.getContent(FILE) : null;

	static function reset(?packs:Map<String, Dynamic>):Void
	{
		if(FileSystem.exists(FILE))
		{
			if(FileSystem.isDirectory(FILE)) FileSystem.deleteDirectory(FILE);
			else FileSystem.deleteFile(FILE);
		}
		Mods.packs = packs == null ? [] : packs;
		ModSecurity.reloadPlayerOverrides();
	}

	static function main():Void
	{
		// ModSecurity mirrors every message to trace(); keep the spec output readable.
		haxe.Log.trace = function(value:Dynamic, ?infos:haxe.PosInfos) {};

		enabledByDefault();
		playerTurnsItOffAndOn();
		playerOverridesPackOptOut();
		packAllowlistIsKept();
		looseScriptsCannotBeSwitchedOff();
		choicesSurviveARestart();
		importedFilesStartSandboxed();
		damagedFileFallsBackToDefaults();
		unwritableFileIsReported();
		logMessages();

		Sys.println('ModSecurityPlayerSpec: all $checks checks passed');
	}

	static function enabledByDefault():Void
	{
		reset();
		var status = ModSecurity.getStatus('Plain');
		check(status.folder == 'Plain', 'status names the folder');
		check(status.enabled && status.packEnabled, 'ModSecurity is on for a mod nobody touched');
		check(status.playerOverride == null, 'no player choice by default');
		check(status.allowlist.length == 0, 'no exceptions by default');
		check(ModSecurity.getPlayerOverride('Plain') == null, 'no stored choice by default');

		var decision = lua('Plain');
		check(blocked(decision), 'default: the unsafe script is blocked');
		check(decision.playerOverride == null, 'default: the decision carries no player choice');
		check(fileText() == null, 'looking a mod up never creates $FILE');
	}

	static function playerTurnsItOffAndOn():Void
	{
		reset();
		check(blocked(lua('Plain')), 'starts sandboxed (and primes the decision cache)');

		check(ModSecurity.setEnabled('Plain', false), 'turning it off is saved');
		var status = ModSecurity.getStatus('Plain');
		check(!status.enabled && status.packEnabled, 'off by the player although pack.json keeps it on');
		check(status.playerOverride == false, 'the choice is an explicit "off"');
		check(fileText() == 'Plain|0', 'stored as <folder>|0, got: ${fileText()}');

		var decision = lua('Plain');
		check(unrestricted(decision), 'off: nothing is scanned, the script may load');
		check(decision.playerOverride == false, 'off: the decision says the player chose it');
		check(blocked(lua('Other')), 'off is per mod: another mod stays sandboxed');

		check(ModSecurity.setEnabled('Plain', false), 'turning it off twice is harmless');
		check(fileText() == 'Plain|0', 'no duplicate entry');

		check(ModSecurity.setEnabled('Plain', true), 'turning it back on is saved');
		check(ModSecurity.getPlayerOverride('Plain') == null, 'back at the default: the choice is forgotten');
		check(fileText() == null, 'an empty choice list removes $FILE');
		check(blocked(lua('Plain')), 'on again: the unsafe script is blocked without a restart');
	}

	static function playerOverridesPackOptOut():Void
	{
		for(pack in ([{scriptSandbox: false}, {allowUnsafeScripts: true}, {scriptSecurity: {enabled: false}}]:Array<Dynamic>))
		{
			reset(['Native' => pack]);
			var status = ModSecurity.getStatus('Native');
			check(!status.enabled && !status.packEnabled && status.playerOverride == null, 'pack.json opt-out still works on its own: $pack');
			var decision = lua('Native');
			check(unrestricted(decision) && decision.playerOverride == null, 'pack.json opt-out is not a player choice: $pack');
		}

		reset(['Native' => {scriptSandbox: false}]);
		check(ModSecurity.setEnabled('Native', true), 'forcing it on is saved');
		var status = ModSecurity.getStatus('Native');
		check(status.enabled && !status.packEnabled && status.playerOverride == true, 'the player wins over a pack.json opt-out');
		check(fileText() == 'Native|1', 'stored as <folder>|1, got: ${fileText()}');
		var decision = lua('Native');
		check(blocked(decision) && decision.playerOverride == true, 'forced on: the unsafe script is blocked');

		check(ModSecurity.setEnabled('Native', false), 'giving the mod its opt-out back is saved');
		check(ModSecurity.getPlayerOverride('Native') == null, 'matches pack.json again: the choice is forgotten');
		check(fileText() == null, 'nothing left to store');
		check(unrestricted(lua('Native')), 'pack.json opt-out applies again');

		// An explicit choice outlives a pack.json that changes its mind later.
		reset();
		ModSecurity.setEnabled('Updated', false);
		Mods.packs = ['Updated' => {scriptSandbox: false}];
		ModSecurity.clearCache();
		check(ModSecurity.getStatus('Updated').playerOverride == false && unrestricted(lua('Updated')), 'still off after the mod opts out too');
		Mods.packs = [];
		ModSecurity.clearCache();
		check(unrestricted(lua('Updated')), 'still off after the mod drops its opt-out');
	}

	static function packAllowlistIsKept():Void
	{
		reset(['Listed' => {scriptSandboxAllowlist: ['lua.os']}]);
		var decision = lua('Listed');
		check(decision.sandboxed && decision.findings.length == 0, 'pack.json allowlist exempts its rule');
		check(ModSecurity.getStatus('Listed').allowlist.join(',') == 'lua.os', 'status lists the exemptions');

		ModSecurity.setEnabled('Listed', false);
		check(unrestricted(lua('Listed')), 'off also ignores the allowlist');
		ModSecurity.setEnabled('Listed', true);
		decision = lua('Listed');
		check(decision.sandboxed && decision.findings.length == 0, 'back on: the allowlist is honoured as before');
		var other = ModSecurity.checkScript('mods/Listed/scripts/io.lua', "io.open('x')", 'lua');
		check(other.sandboxed && other.findings.length == 1, 'back on: rules outside the allowlist still block');
	}

	static function looseScriptsCannotBeSwitchedOff():Void
	{
		reset();
		check(!ModSecurity.setEnabled('', false), 'no folder, no switch');
		check(!ModSecurity.setEnabled(null, false), 'null folder, no switch');
		check(!ModSecurity.setPlayerOverride('  ', false), 'blank folder, no switch');
		check(!ModSecurity.setPlayerOverride('two\nlines', false), 'a folder name cannot span lines');
		check(fileText() == null, 'rejected choices are not stored');

		var status = ModSecurity.getStatus('');
		check(status.folder == '' && status.enabled && status.playerOverride == null, 'loose content reports as always on');

		// Hand-written entries for the shared loose folders change nothing either.
		File.saveContent(FILE, 'scripts|0\ndata|0\nsongs|0');
		ModSecurity.reloadPlayerOverrides();
		for(path in ['mods/scripts/loose.lua', 'mods/data/song/loose.lua', 'mods/songs/song/loose.lua'])
		{
			var decision = ModSecurity.checkScript(path, UNSAFE_LUA, 'lua');
			check(decision.sandboxed && decision.findings.length == 1 && decision.modFolder == null, 'loose script stays sandboxed: $path');
		}
	}

	static function choicesSurviveARestart():Void
	{
		reset(['Native' => {scriptSandbox: false}]);
		ModSecurity.setEnabled('b mod', false);
		ModSecurity.setEnabled('Native', true);
		ModSecurity.setEnabled('A-mod', false);
		check(fileText() == 'A-mod|0\nNative|1\nb mod|0', 'one sorted line per choice, got: ${fileText()}');

		// What a fresh process sees: nothing in memory, only the file.
		ModSecurity.reloadPlayerOverrides();
		check(ModSecurity.getPlayerOverride('A-mod') == false, 'off is read back');
		check(ModSecurity.getPlayerOverride('b mod') == false, 'folder names with spaces are read back');
		check(ModSecurity.getPlayerOverride('Native') == true, 'forced on is read back');
		check(ModSecurity.getPlayerOverride('a-mod') == null, 'folder names are matched exactly');
		check(unrestricted(lua('A-mod')) && unrestricted(lua('b mod')) && blocked(lua('Native')), 'the stored choices drive script loading');

		// Edited by hand while the game was closed (Notepad: BOM, CRLF, stray spaces).
		File.saveContent(FILE, String.fromCharCode(0xFEFF) + 'Win Mod|0\r\nTrailing|1  \r\n  Padded|0\r\n\r\n');
		ModSecurity.reloadPlayerOverrides();
		check(ModSecurity.getPlayerOverride('Win Mod') == false, 'BOM and CRLF are tolerated');
		check(ModSecurity.getPlayerOverride('Trailing') == true, 'spaces after the flag are tolerated');
		check(ModSecurity.getPlayerOverride('Padded') == null, 'a padded line does not name the unpadded folder');
		check(blocked(lua('Padded')), 'so a sloppy line cannot switch a mod off');
		check(ModSecurity.getPlayerOverride('A-mod') == null, 'the file is the source of truth after a reload');

		// A folder that really carries padding keeps its own choice and shares it with nobody.
		reset();
		check(ModSecurity.setEnabled(' Odd', false), 'a padded folder name can be stored');
		check(fileText() == ' Odd|0', 'the name is written as it is, got: ${fileText()}');
		ModSecurity.reloadPlayerOverrides();
		check(unrestricted(lua(' Odd')), 'and is read back for that folder');
		check(blocked(lua('Odd')), 'while the similarly named folder stays sandboxed');

		var text = ModSecurity.serializePlayerOverrides(ModSecurity.parsePlayerOverrides('z|1\na|0\nm|1'));
		check(text == 'a|0\nm|1\nz|1', 'serialize(parse(x)) is stable and sorted, got: $text');
	}

	static function importedFilesStartSandboxed():Void
	{
		// A .zip imported into a folder brings new files: "off" was about the old ones.
		reset(['Native' => {scriptSandbox: false}]);
		ModSecurity.setEnabled('Trusted', false);
		ModSecurity.setEnabled('Other', false);
		ModSecurity.setEnabled('Native', true);
		check(ModSecurity.revokePlayerOptOut('Trusted'), 'an "off" choice is dropped when the folder gets new files');
		check(blocked(lua('Trusted')), 'so the imported mod is sandboxed again');
		check(ModSecurity.getStatus('Trusted').playerOverride == null, 'and follows its own pack.json from here on');
		check(fileText() == 'Native|1\nOther|0', 'only that line leaves the file, got: ${fileText()}');
		check(unrestricted(lua('Other')), 'other mods keep their choice');

		check(!ModSecurity.revokePlayerOptOut('Native'), 'a forced "on" is not an opt-out');
		check(blocked(lua('Native')), 'and stays in force for the new files');
		check(!ModSecurity.revokePlayerOptOut('Plain'), 'nothing to drop for a mod without a choice');
		check(!ModSecurity.revokePlayerOptOut('') && !ModSecurity.revokePlayerOptOut(null), 'nor for loose content');
		check(fileText() == 'Native|1\nOther|0', 'none of that touched the file');

		// What the menu does next: it is rebuilt and reads the file again.
		ModSecurity.reloadPlayerOverrides();
		check(blocked(lua('Trusted')) && unrestricted(lua('Other')) && blocked(lua('Native')), 'the result survives the reload');
	}

	static function damagedFileFallsBackToDefaults():Void
	{
		var parsed = ModSecurity.parsePlayerOverrides([
			'no separator at all',
			'|0',
			'   |1',
			'Mod|2',
			'Mod|',
			'Mod|yes',
			'Good|0',
			'Pipe|Name|1',
			'Good|0',
			''
		].join('\n'));
		check([for(folder in parsed.keys()) folder].length == 2, 'only well-formed lines count');
		check(parsed.get('Good') == false, 'well-formed "off" line');
		check(parsed.get('Pipe|Name') == true, 'the flag is whatever follows the last separator');
		check(!parsed.exists('Mod'), 'unknown flags never turn the sandbox off');
		check([for(folder in ModSecurity.parsePlayerOverrides(null).keys()) folder].length == 0, 'null text');
		check([for(folder in ModSecurity.parsePlayerOverrides('').keys()) folder].length == 0, 'empty text');

		reset();
		File.saveContent(FILE, 'Mod|2\ngarbage');
		ModSecurity.reloadPlayerOverrides();
		check(blocked(lua('Mod')), 'a damaged file leaves the mod sandboxed');
	}

	static function unwritableFileIsReported():Void
	{
		reset();
		// A directory in the way makes both reading and writing the file fail.
		FileSystem.createDirectory(FILE);
		ModSecurity.reloadPlayerOverrides();
		check(blocked(lua('Plain')), 'unreadable choices mean the default policy');
		check(!ModSecurity.setEnabled('Plain', false), 'a failed save is reported to the caller');
		check(unrestricted(lua('Plain')), 'the choice still applies for now');
		ModSecurity.reloadPlayerOverrides();
		check(blocked(lua('Plain')), 'but it is gone once the choices are read again');
		reset();
	}

	static function logMessages():Void
	{
		var lines:Array<String> = [];
		var sink = function(message:String) lines.push(message);
		var count = function(needle:String):Int return [for(line in lines) if(line.indexOf(needle) != -1) line].length;

		// Turned off by the player: one warning per mod, worded differently from pack.json.
		reset(['Native' => {scriptSandbox: false}]);
		ModSecurity.setEnabled('Plain', false);
		ModSecurity.report(lua('Plain'), sink);
		ModSecurity.report(lua('Plain'), sink);
		check(lines.length == 1, 'one warning for a mod the player trusts, got: $lines');
		check(lines[0] == '[ModSecurity] WARNING: ModSecurity is turned off for mod "Plain" in the Mods menu (Mod Info). '
			+ 'Its Lua/Python/HScript scripts run with full engine privileges.', 'player warning text: ${lines[0]}');

		lines = [];
		ModSecurity.report(lua('Native'), sink);
		check(lines.length == 1 && lines[0] == '[ModSecurity] WARNING: mod "Native" opted out of script sandboxing in pack.json. '
			+ 'Its Lua/Python/HScript scripts run with full engine privileges.', 'pack.json warning text is unchanged: $lines');

		// Blocked script of a named mod: the report ends with where the switch is, once per mod.
		lines = [];
		ModSecurity.report(lua('Blocked'), sink);
		check(lines.length == 3, 'BLOCKED line, finding line and one hint, got: $lines');
		check(lines[0].indexOf('[ModSecurity] BLOCKED lua script "scripts/payload.lua" from mod "Blocked"') == 0, 'block line: ${lines[0]}');
		check(lines[1].indexOf('rule=lua.os') != -1, 'finding line: ${lines[1]}');
		check(lines[2] == '[ModSecurity] Only if you trust mod "Blocked": Mod Info in the Mods menu can turn ModSecurity off '
			+ 'for it, which lets its blocked scripts run.', 'hint text: ${lines[2]}');
		ModSecurity.report(lua('Blocked'), sink);
		check(lines.length == 5 && count('Mod Info') == 1, 'the hint is not repeated for the same mod, got: $lines');

		// Loose scripts have no entry in the Mods menu, so they get no hint.
		lines = [];
		ModSecurity.report(ModSecurity.checkScript('mods/scripts/loose.lua', UNSAFE_LUA, 'lua'), sink);
		check(lines.length == 2 && count('Mod Info') == 0, 'no hint for loose scripts, got: $lines');

		// A file that is not readable text would not run with ModSecurity off either: no hint for it.
		lines = [];
		var utf16:String = 'p' + String.fromCharCode(0) + 'r' + String.fromCharCode(0);
		ModSecurity.report(ModSecurity.checkScript('mods/Encoded/scripts/utf16.lua', utf16, 'lua'), sink);
		check(lines.length == 2 && count('rule=security.binary-source') == 1 && count('Mod Info') == 0,
			'no hint for a file with NUL bytes, got: $lines');
		lines = [];
		ModSecurity.report(ModSecurity.checkScript('mods/Encoded/scripts/gone.lua', null, 'lua'), sink);
		check(lines.length == 2 && count('rule=security.unreadable') == 1 && count('Mod Info') == 0,
			'no hint for a file that could not be read, got: $lines');
		lines = [];
		ModSecurity.report(lua('Encoded'), sink);
		check(lines.length == 3 && count('Mod Info') == 1, 'the hint is still due for a real finding in that mod, got: $lines');
		lines = [];
		ModSecurity.report(ModSecurity.checkScript('mods/Mixed/scripts/both.lua', UNSAFE_LUA + String.fromCharCode(0), 'lua'), sink);
		check(count('rule=security.binary-source') == 1 && count('rule=lua.os') == 1 && count('Mod Info') == 1,
			'a NUL byte next to a real finding keeps the hint, got: $lines');

		// Changing the choice lets the matching message appear again.
		lines = [];
		ModSecurity.setEnabled('Blocked', false);
		ModSecurity.report(lua('Blocked'), sink);
		check(lines.length == 1 && count('turned off for mod "Blocked"') == 1, 'warning after switching it off, got: $lines');
		ModSecurity.setEnabled('Blocked', true);
		lines = [];
		ModSecurity.report(lua('Blocked'), sink);
		check(lines.length == 3 && count('Mod Info') == 1, 'block report (with hint) after switching it back on, got: $lines');

		// Forced on over a pack.json opt-out: blocked like any other mod.
		lines = [];
		ModSecurity.setEnabled('Native', true);
		ModSecurity.report(lua('Native'), sink);
		check(lines.length == 3 && count('WARNING') == 0 && count('BLOCKED') == 1, 'forced on: block report, no opt-out warning, got: $lines');
		reset();
	}
}
