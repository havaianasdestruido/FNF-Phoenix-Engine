import backend.ScriptSecurityScanner;
import backend.ScriptSecurityScanner.ScriptSecurityFinding;

/** Dependency-free contract tests for the softmod source scanner. */
class ModSecuritySpec
{
	static function check(value:Bool, label:String):Void
	{
		if(!value) throw label;
	}

	static function has(findings:Array<ScriptSecurityFinding>, rule:String, line:Int):Bool
	{
		for(finding in findings)
			if(finding.rule == rule && finding.line == line) return true;
		return false;
	}

	static function main():Void
	{
		var normalLua = ScriptSecurityScanner.scan([
			'function onCreate()',
			"  setProperty('health', 1)",
			'end'
		].join('\n'), 'lua');
		check(normalLua.length == 0, 'normal Lua hooks must remain available');

		var lua = ScriptSecurityScanner.scan([
			'function onCreate()',
			"  os.execute('python -c evil.py')",
			"  local f = io.open('secret.txt')",
			'end'
		].join('\r\n'), 'lua');
		check(has(lua, 'lua.os', 2), 'os.execute line/rule');
		check(has(lua, 'process.shell', 2), 'python -c line/rule');
		check(has(lua, 'lua.io', 3), 'io.open line/rule');

		var python = ScriptSecurityScanner.scan([
			'def onCreate():',
			'    import os',
			"    debugPrint('http://example.invalid')"
		].join('\n'), 'python');
		check(has(python, 'python.dangerous-import', 2), 'Python import line/rule');
		check(has(python, 'network.url', 3), 'URL line/rule');

		var comments = ScriptSecurityScanner.scan([
			'-- os.execute is documented here',
			'function onBeatHit() end'
		].join('\n'), 'lua');
		check(comments.length == 0, 'comment-only Lua lines are ignored');
		var afterLongComment = ScriptSecurityScanner.scan("--[[comment]] os.execute('bad')", 'lua');
		check(has(afterLongComment, 'lua.os', 1), 'code after a closed long comment is scanned');

		var allowlisted = ScriptSecurityScanner.scan("io.open('mod-data.txt')", 'lua', ['lua.io']);
		check(allowlisted.length == 0, 'exact per-mod allowlist rule');

		var haxe = ScriptSecurityScanner.scan([
			'Sys.command("calc");',
			'sys.io.File.saveContent("x", "y");',
			'var cls = Type.resolveClass("sys.io.File");'
		].join('\n'), 'haxe');
		check(has(haxe, 'haxe.process', 1), 'HScript process call');
		check(has(haxe, 'haxe.filesystem', 2), 'HScript file call');
		check(has(haxe, 'haxe.reflection', 3), 'HScript class resolution');

		var safeReflection = ScriptSecurityScanner.scan("getPropertyFromClass('flixel.FlxG', 'width')", 'python');
		check(safeReflection.length == 0, 'normal game-state reflection stays available');
		var unsafeReflection = ScriptSecurityScanner.scan("getPropertyFromClass('sys.io.File', 'getContent')", 'python');
		check(has(unsafeReflection, 'engine.native-class', 1), 'privileged reflection is blocked');

		Sys.println('Mod security scanner tests passed');
	}
}
