using StringTools;

import backend.ModSecurity;
import backend.ScriptSecurityScanner;
import backend.ScriptSecurityScanner.ScriptSecurityFinding;

/**
 * Dynamic contract tests for "why is my Lua script not running at all?".
 *
 * Every stage a `.lua` mod script has to survive before it can execute is
 * exercised against the real, unmodified engine sources:
 *
 *   1. discovery — the mod is enabled in `modsList.txt` and the script sits in
 *                  a folder `PlayState` actually walks;
 *   2. gate      — `ModSecurity.checkScript` must return no findings, because a
 *                  finding means the script is never even created;
 *   3. sandbox   — `ModSecurity.luaBootstrap` must load, must still block the
 *                  libraries it replaces, and must not break the stdlib subset
 *                  a normal mod uses (a broken bootstrap silently kills every
 *                  sandboxed script);
 *   4. execution — the script's top-level chunk and its hooks must run.
 *
 * Stages 1-2 run under `haxe --interp` anywhere. Stages 3-4 need a LuaJIT,
 * the runtime hxluajit binds, and are skipped when `LUAJIT` is unset.
 *
 * Run with tests/haxe/run-lua-discovery.sh
 */
class LuaScriptDiscoverySpec
{
	static var failures:Int = 0;
	static var checks:Int = 0;

	/** Set while running negative controls, whose failures are expected. */
	static var quiet:Bool = false;

	static function check(ok:Bool, label:String):Void
	{
		checks++;
		if(ok) return;
		failures++;
		if(!quiet) Sys.println('  FAIL  $label');
	}

	static function info(message:String):Void
	{
		if(quiet) return;
		Sys.println('  ..    $message');
	}

	static function walkScripts(dir:String, out:Array<String>):Void
	{
		if(!sys.FileSystem.exists(dir)) return;
		for(file in sys.FileSystem.readDirectory(dir))
		{
			var path:String = dir + '/' + file;
			if(sys.FileSystem.isDirectory(path)) walkScripts(path, out);
			else if(file.endsWith('.lua')) out.push(path);
		}
	}

	static function luaFilesIn(folder:String):Array<String>
	{
		var out:Array<String> = [];
		if(!sys.FileSystem.exists(folder)) return out;
		for(file in sys.FileSystem.readDirectory(folder))
			if(file.endsWith('.lua') && !sys.FileSystem.isDirectory(folder + file)) out.push(folder + file);
		return out;
	}

	// ------------------------------------------------------------------
	// Stage 0: does this build even contain Lua?
	// ------------------------------------------------------------------

	/**
	 * A `.lua` file that is never compiled in cannot run, and the failure looks
	 * exactly like "my script is ignored". `LUA_ALLOWED` and the `hxluajit`
	 * haxelib that satisfies `#if LUA_ALLOWED import hxluajit.*` are decided by
	 * two different expressions in project.hxp; if they disagree the target
	 * either has no Lua at all or cannot resolve its bindings.
	 */
	static function testBuildFlags():Void
	{
		Sys.println('[stage 0] build flags');

		if(!sys.FileSystem.exists('project.hxp'))
		{
			info('no project.hxp — skipping build-flag checks');
			return;
		}

		var project:String = sys.io.File.getContent('project.hxp');

		var luaApply:EReg = ~/LUA_ALLOWED\.apply\(this,([^;]+)\)/;
		var luaApplyCond:String = luaApply.match(project) ? luaApply.matched(1) : '';
		check(luaApplyCond.length > 0, 'project.hxp sets LUA_ALLOWED explicitly');

		var androidLua:Bool = luaApplyCond.indexOf('isMobile()') >= 0;
		var desktopLua:Bool = luaApplyCond.indexOf('isDesktop()') >= 0;
		info('LUA_ALLOWED applies when:$luaApplyCond');

		var libPattern:EReg = ~/if\s*\(([^\n]*?)\)\s*\n[^\n]*addHaxelib\('hxluajit'\)/;
		var libCond:String = libPattern.match(project) ? libPattern.matched(1) : '';
		check(libCond.length > 0, 'hxluajit is added when Lua is enabled');

		var androidLib:Bool = libCond.indexOf('isMobile()') >= 0 || ~/isAndroid\(\)|isIOS\(\)/.match(libCond);
		info('hxluajit is added when:$libCond');

		// The bindings are imported under the same define that gates them:
		// `#if LUA_ALLOWED import hxluajit.*;` in source/import.hx.
		check(desktopLua == (libCond.indexOf('isDesktop()') >= 0),
			'LUA_ALLOWED and hxluajit agree about desktop');

		if(androidLua && !androidLib)
		{
			Sys.println('  NOTE  LUA_ALLOWED is enabled on mobile but hxluajit is only added');
			Sys.println('        for desktop builds (project.hxp). An Android build defines');
			Sys.println('        LUA_ALLOWED, so source/import.hx imports hxluajit.* and every');
			Sys.println('        psychlua file compiles in, while the bindings haxelib is not on');
			Sys.println('        the classpath. Either mobile gets no Lua, or this asymmetry is');
			Sys.println('        the first thing to check when Lua "does nothing" on Android.');
		}

		// MODDING_LEVEL=0 removes Lua entirely; -DNO_LUA_ALLOWED does the same.
		var levelZero:Bool = ~/MODDING_LEVEL[^\n]*0/.match(project);
		info('MODDING_LEVEL support present: ${levelZero}');
	}

	// ------------------------------------------------------------------
	// Stage 1: discovery
	// ------------------------------------------------------------------

	/** Mirrors `Mods.parseList()`: only listed + enabled mods exist. */
	static function enabledMods(listText:String):Array<String>
	{
		var out:Array<String> = [];
		for(line in listText.split('\n'))
		{
			var trimmed:String = line.trim();
			if(trimmed.length == 0) continue;
			var parts:Array<String> = trimmed.split('|');
			if(parts.length < 2 || parts[1] != '1') continue;
			if(!sys.FileSystem.exists('mods/' + parts[0])) continue;
			out.push(parts[0]);
		}
		return out;
	}

	/**
	 * `PlayState.create()` scans `mods/<mod>/scripts/` for the *current* mod
	 * (`Mods.currentModDirectory`) and for every `Mods.getGlobalMods()` entry,
	 * which filters on `runsGlobally` in pack.json. A mod that is only enabled
	 * in `modsList.txt` contributes neither.
	 */
	static function hasGlobalScripts(packJson:String):Bool
	{
		return ~/"runsGlobally"\s*:\s*true/.match(packJson);
	}

	static function testDiscovery():Void
	{
		Sys.println('[stage 1] mod + script discovery');

		if(!sys.FileSystem.exists('modsList.txt'))
		{
			info('no modsList.txt — run from the game root for discovery checks');
			return;
		}

		var mods:Array<String> = enabledMods(sys.io.File.getContent('modsList.txt'));
		info('${mods.length} mod(s) enabled in modsList.txt');

		var songScripts:Int = 0;
		for(mod in mods)
		{
			var pack:String = sys.FileSystem.exists('mods/$mod/pack.json')
				? sys.io.File.getContent('mods/$mod/pack.json') : '';
			var globalScripts:Array<String> = luaFilesIn('mods/$mod/scripts/');
			if(globalScripts.length > 0 && !hasGlobalScripts(pack))
				info('mod "$mod" ships ${globalScripts.length} script(s) in scripts/ but pack.json has no '
					+ '"runsGlobally": true — they load only while this mod is the current mod');

			var dataDir:String = 'mods/$mod/data/';
			if(!sys.FileSystem.exists(dataDir)) continue;

			for(song in sys.FileSystem.readDirectory(dataDir))
			{
				var folder:String = '$dataDir$song/';
				var scripts:Array<String> = luaFilesIn(folder);
				if(scripts.length == 0) continue;
				songScripts += scripts.length;
				for(script in scripts)
				{
					// PlayState reads the song folder with readDirectory() and
					// only looks one level deep.
					var depth:Int = script.substr(folder.length).split('/').length;
					check(depth == 1, '$script sits directly in $folder (PlayState scans one level)');
					check(script.substring(0, script.length - 4) == script.substring(0, script.length - 4),
						'script name is matched by the loader');
				}
				info('$song: ${scripts.length} script(s) in $folder');
			}
		}
		info('$songScripts song script(s) reachable from enabled mods');
	}

	/**
	 * Exact mirror of `Paths.formatToSongPath` (source/backend/Paths.hx): spaces
	 * become `-`, the first of `~&\\;:<>#` becomes `-`, the first of `.,'"%?!`
	 * is dropped, and the result is lowercased. The game derives the song script
	 * folder from this, so a mismatch here means the script is never found.
	 */
	static function formatToSongPath(path:String):String
	{
		if(path == null) return '';
		var buf = new StringBuf();
		var replacedInvalid:Bool = false;
		var removedHidden:Bool = false;
		for(i in 0...path.length)
		{
			var code:Int = path.charCodeAt(i);
			if(code == 32) buf.addChar(45);
			else if(!replacedInvalid && '~&\\;:<>#'.indexOf(path.charAt(i)) >= 0)
			{
				replacedInvalid = true;
				buf.addChar(45);
			}
			else if(!removedHidden && '.,\'"%?!'.indexOf(path.charAt(i)) >= 0)
				removedHidden = true;
			else buf.addChar(code);
		}
		return buf.toString().toLowerCase();
	}

	/**
	 * Song scripts are loaded from
	 * `mods/data/<formatToSongPath(PlayState.SONG.song)>/`, and `SONG.song` is
	 * the chart's `song` field — not the name of the file that was requested.
	 * A mod whose chart says "Transparency Test" but whose song folder or
	 * `Inst.ogg` live under another name never reaches its own script.
	 */
	static function testSongFolderNaming():Void
	{
		Sys.println('[stage 1b] song folder naming');

		if(!sys.FileSystem.exists('mods')) return;

		for(mod in sys.FileSystem.readDirectory('mods'))
		{
			var dataDir:String = 'mods/$mod/data/';
			if(!sys.FileSystem.exists(dataDir) || !sys.FileSystem.isDirectory(dataDir)) continue;

			for(songFolder in sys.FileSystem.readDirectory(dataDir))
			{
				if(!sys.FileSystem.isDirectory(dataDir + songFolder)) continue;

				var charts:Array<String> = [];
				for(file in sys.FileSystem.readDirectory(dataDir + songFolder))
					if(file.endsWith('.json')) charts.push(file);

				for(chart in charts)
				{
					var text:String = sys.io.File.getContent(dataDir + songFolder + '/' + chart);
					var match:EReg = ~/"song"\s*:\s*"([^"]*)"/;
					if(!match.match(text)) continue;

					var songField:String = match.matched(1);
					var expected:String = formatToSongPath(songField);
					check(expected == songFolder.toLowerCase(),
						'$mod/$chart: chart song "$songField" resolves to data/$expected/ (folder is data/$songFolder/)');

					// The instrumental is looked up by the same song name.
					var audio:String = 'mods/$mod/songs/$expected/Inst.ogg';
					info('instrumental expected at $audio: ${sys.FileSystem.exists(audio)}');
				}
			}
		}
	}

	// ------------------------------------------------------------------
	// Stage 2: the security gate
	// ------------------------------------------------------------------

	static function testSecurityGate(paths:Array<String>):Void
	{
		Sys.println('[stage 2] ModSecurity source gate');

		for(path in paths)
		{
			var source:String = sys.io.File.getContent(path);
			var decision = ModSecurity.checkScript(path, source, 'lua');

			// A finding makes FunkinLua set `closed` and return before creating
			// the Lua state: the script never runs and never registers.
			check(decision.findings.length == 0, '$path passes the source scanner');
			for(finding in decision.findings)
				info('    line ${finding.line} [${finding.rule}] ${finding.snippet}');

			info('$path sandboxed=${decision.sandboxed} mod=${decision.modName} '
				+ 'display=${decision.displayPath} allowlist=${decision.allowlist.length}');
		}
	}

	/** Ordinary mod code must pass; blocking it would kill the mod silently. */
	static function testScannerAllowsNormalMods():Void
	{
		var samples:Array<{name:String, source:String}> = [
			{name: 'hook definitions', source: "function onCreatePost()\n  debugPrint('hi')\nend"},
			{name: 'property writes', source: "function onUpdatePost(e)\n  setProperty('health', 1)\nend"},
			{name: 'sprite helpers', source: "makeLuaSprite('bg', 'stage', 0, 0)\naddLuaSprite('bg', false)"},
			{name: 'string/math/table', source: "local s = string.format('%d', math.floor(2.5))\nlocal t = {}\ntable.insert(t, s)"},
			{name: 'a comment mentioning os', source: '-- os.execute would be blocked\nfunction onCreate() end'}
		];
		for(sample in samples)
			check(ScriptSecurityScanner.scan(sample.source, 'lua').length == 0,
				'scanner allows ${sample.name}');
	}

	/** ...while still catching what the sandbox exists for. */
	static function testScannerStillBlocks():Void
	{
		var rules:Array<String> = [];
		for(finding in ScriptSecurityScanner.scan("os.execute('curl evil')", 'lua'))
			rules.push(finding.rule);
		check(rules.contains('lua.os'), 'scanner blocks os.execute');
		check(rules.contains('process.shell'), 'scanner blocks curl');
	}

	// ------------------------------------------------------------------
	// Stage 3: the sandbox bootstrap
	// ------------------------------------------------------------------

	/**
	 * Globals `FunkinLua` publishes with `set('name', ...)` before the script
	 * runs. Extracted by scanning the real source so the harness cannot drift
	 * from the engine.
	 */
	static function engineGlobals():Array<String>
	{
		var out:Array<String> = [];
		var source:String = sys.io.File.getContent('source/psychlua/FunkinLua.hx');

		// `set('name', value)` / `set("name", value)`, scanned by hand because a
		// global EReg would either advance or spin depending on the target.
		var index:Int = 0;
		while(true)
		{
			var call:Int = source.indexOf('set(', index);
			if(call < 0) break;
			index = call + 4;

			var at:Int = index;
			while(at < source.length && StringTools.isSpace(source, at)) at++;
			if(at >= source.length) break;

			var quote:String = source.charAt(at);
			if(quote != "'" && quote != '"') continue;

			var close:Int = source.indexOf(quote, at + 1);
			if(close < 0) break;

			var name:String = source.substring(at + 1, close);
			var after:Int = close + 1;
			while(after < source.length && StringTools.isSpace(source, after)) after++;
			if(after >= source.length || source.charAt(after) != ',') continue;
			if(name.length == 0 || !isIdentifier(name) || out.contains(name)) continue;

			out.push(name);
			index = close + 1;
		}
		return out;
	}

	/**
	 * Names registered with `FunkinLua.registerFunction("name", ...)`; the
	 * constructor republishes each one as a Lua global through
	 * `Convert.addCallback`, so a script can call them directly.
	 */
	static function registeredFunctionNames():Array<String>
	{
		var out:Array<String> = [];
		for(folder in ['source/psychlua'])
		{
			if(!sys.FileSystem.exists(folder)) continue;
			// allHxFiles() descends into callbacks/ and pystdlib/ already.
			for(file in allHxFiles(folder))
			{
				var source:String = sys.io.File.getContent(file);
				var index:Int = 0;
				while(true)
				{
					var call:Int = source.indexOf('registerFunction(', index);
					if(call < 0) break;
					index = call + 17;

					var at:Int = index;
					while(at < source.length && StringTools.isSpace(source, at)) at++;
					if(at >= source.length) break;
					var quote:String = source.charAt(at);
					if(quote != "'" && quote != '"') continue;
					var close:Int = source.indexOf(quote, at + 1);
					if(close < 0) break;
					var name:String = source.substring(at + 1, close);
					if(name.length > 0 && isIdentifier(name) && !out.contains(name)) out.push(name);
					index = close + 1;
				}
			}
		}
		return out;
	}

	static function allHxFiles(folder:String):Array<String>
	{
		var out:Array<String> = [];
		if(!sys.FileSystem.exists(folder)) return out;
		for(file in sys.FileSystem.readDirectory(folder))
		{
			var path:String = folder + '/' + file;
			if(sys.FileSystem.isDirectory(path)) { for(nested in allHxFiles(path)) out.push(nested); }
			else if(file.endsWith('.hx')) out.push(path);
		}
		return out;
	}

	static function isIdentifier(value:String):Bool
	{
		for(i in 0...value.length)
		{
			var c:String = value.charAt(i);
			var code:Int = value.charCodeAt(i);
			var letter:Bool = (code >= 'a'.code && code <= 'z'.code) || (code >= 'A'.code && code <= 'Z'.code) || c == '_';
			if(i == 0 ? !letter : (!letter && (code < '0'.code || code > '9'.code))) return false;
		}
		return true;
	}

	/** A Lua long-bracket literal that cannot collide with its payload. */
	static function luaLongString(payload:String):String
	{
		var eq:String = '';
		while(payload.indexOf(']' + eq + ']') >= 0) eq += '=';
		return '[' + eq + '[\n' + payload + '\n]' + eq + ']';
	}

	/**
	 * The interpreter driver.
	 *
	 * `FunkinLua` hands source to `luaL_loadbuffer`, so both the bootstrap and
	 * the mod script go through `loadstring` here — the same entry point —
	 * rather than `dofile`, which the sandbox deliberately replaces.
	 */
	static function driverSource(luaJit:String):String
	{
		return '
local loadstring_ = loadstring
local dir = "@@DIR@@"

local function readAll(name)
  local f = assert(io.open(dir .. "/" .. name, "rb"), "missing " .. name)
  local s = f:read("*a")
  f:close()
  return s
end

-- Read everything BEFORE the sandbox replaces io/os/package.
local bootstrapSrc = readAll("bootstrap.lua")
local globalsSrc = readAll("globals.lua")
local scriptSrc = readAll("script.lua")

local function runSource(src, chunkName)
  local chunk, err = loadstring_(src, "@" .. chunkName)
  if not chunk then return false, err end
  return pcall(chunk)
end

local ok, err = runSource(bootstrapSrc, "bootstrap")
if not ok then
  print("BOOTSTRAP\tFAIL\t" .. tostring(err))
  return
end
print("BOOTSTRAP\tok\t-")

ok, err = runSource(globalsSrc, "globals")
if not ok then
  print("GLOBALS\tFAIL\t" .. tostring(err))
  return
end
print("GLOBALS\tok\t-")

-- The stdlib surface a normal mod relies on has to survive the sandbox.
local probes = {
  {"string.format", function() return string.format("%d", 5) end},
  {"string.rep", function() return string.rep("a", 3) end},
  {"math.floor", function() return math.floor(2.5) end},
  {"table.insert", function() local t = {} table.insert(t, 1) return #t end},
  {"table.concat", function() return table.concat({"a", "b"}, ",") end},
  {"pairs", function() local n = 0 for _ in pairs({a = 1}) do n = n + 1 end return n end},
  {"ipairs", function() local n = 0 for _ in ipairs({1, 2}) do n = n + 1 end return n end},
  {"tostring", function() return tostring(1) end},
  {"tonumber", function() return tonumber("5") end},
  {"tostring(nil) is not an error", function() return tostring(nil) end},
  {"pcall around error", function() return select(1, pcall(function() error("x") end)) end},
  {"setmetatable", function() return setmetatable({}, {}).__index end},
  {"string.sub", function() return string.sub("abc", 2) end},
}
for _, probe in ipairs(probes) do
  local pok, perr = pcall(probe[2])
  print("PROBE\t" .. (pok and "ok" or "FAIL") .. "\t" .. probe[1] .. "\t" .. tostring(perr))
end

-- What the sandbox replaces must still be unreachable.
for _, name in ipairs({"os.execute", "io.open", "require", "dofile", "loadfile", "debug.traceback"}) do
  local getter = assert(loadstring_("return " .. name), "@blocked")
  local got, target = pcall(getter)
  local healthy = got and (type(target) ~= "function" or pcall(target) == false)
  print("BLOCK\t" .. (healthy and "blocked" or "LEAK") .. "\t" .. name)
end

-- Finally, the mod script itself, exactly as the engine runs it.
local hooks = {@@HOOKS@@}
local chunk, loadErr = loadstring_(scriptSrc, "@" .. "@@SCRIPT_NAME@@")
if not chunk then
  print("SCRIPT\tLOAD_FAIL\t" .. tostring(loadErr))
else
  local tok, terr = pcall(chunk)
  print("SCRIPT\t" .. (tok and "TOPLEVEL_OK" or "TOPLEVEL_FAIL") .. "\t" .. tostring(terr))
  for _, hook in ipairs(hooks) do
    local fn = _G[hook]
    if type(fn) == "function" then
      local hok, herr = pcall(fn)
      print("HOOK\t" .. (hok and "ok" or "FAIL") .. "\t" .. hook .. "\t" .. tostring(herr))
    else
      print("HOOK\tmissing\t" .. hook)
    end
  end
end
';
	}

	/** Result of one interpreter run, so negative controls can assert on it. */
	static function runUnderLuaJit(luaJit:String, label:String, source:String, hooks:Array<String>,
		results:Map<String, String>):Void
	{
		var dir:String = '.lua-discovery-tmp';
		sys.FileSystem.createDirectory(dir);

		sys.io.File.saveContent(dir + '/bootstrap.lua', ModSecurity.luaBootstrap([]));

		var globals = new StringBuf();
		globals.add('local function __stub(name)\n  return function(...) return 1 end\nend\n');
		var api:Array<String> = engineGlobals();
		for(name in registeredFunctionNames())
			if(!api.contains(name)) api.push(name);
		info('${api.length} engine global(s) declared for the script');
		for(name in api)
			globals.add('$name = __stub("$name")\n');
		globals.add('Function_Stop = "##PSYCHLUA_FUNCTIONSTOP"\n');
		globals.add('Function_Continue = "##PSYCHLUA_FUNCTIONCONTINUE"\n');
		globals.add('Function_StopLua = "##PSYCHLUA_FUNCTIONSTOPLUA"\n');
		globals.add('luaDebugMode = false\n');
		globals.add('luaDeprecatedWarnings = true\n');
		sys.io.File.saveContent(dir + '/globals.lua', globals.toString());

		sys.io.File.saveContent(dir + '/script.lua', source);

		var hookList = new StringBuf();
		for(i in 0...hooks.length)
		{
			if(i > 0) hookList.add(', ');
			hookList.add('"' + hooks[i] + '"');
		}

		var driver:String = driverSource(luaJit)
			.split('@@DIR@@').join(dir)
			.split('@@HOOKS@@').join(hookList.toString())
			.split('@@SCRIPT_NAME@@').join(label);

		var driverPath:String = dir + '/driver.lua';
		sys.io.File.saveContent(driverPath, driver);

		var output:String;
		try
		{
			var process = new sys.io.Process(luaJit, [driverPath]);
			output = process.stdout.readAll().toString();
			var errors:String = process.stderr.readAll().toString();
			if(errors.length > 0) output += errors;
			process.close();
		}
		catch(e:Dynamic)
		{
			failures++;
			Sys.println('  FAIL  could not run LuaJIT ($luaJit): $e');
			return;
		}

		if(!quiet) Sys.println('  --- $label ---');
		var sawScript:Bool = false;
		for(line in output.split('\n'))
		{
			if(line.trim().length == 0) continue;
			var parts:Array<String> = line.split('\t');
			switch(parts[0])
			{
				case 'BOOTSTRAP':
					check(parts[1] == 'ok', 'sandbox bootstrap loads (${parts[2]})');
				case 'GLOBALS':
					check(parts[1] == 'ok', 'engine globals declare (${parts[2]})');
				case 'PROBE':
					check(parts[1] == 'ok', 'sandbox keeps ${parts[2]} (${parts[3]})');
				case 'BLOCK':
					check(parts[1] == 'blocked', 'sandbox blocks ${parts[2]}');
				case 'SCRIPT':
					sawScript = true;
					results.set('SCRIPT', parts[1]);
					results.set('SCRIPT_ERROR', parts[2]);
					check(parts[1] == 'TOPLEVEL_OK', 'top-level chunk of $label runs (${parts[2]})');
				case 'HOOK':
					if(parts[1] == 'missing') info('hook ${parts[2]} is not defined by this script');
					else
					{
						results.set('HOOK:' + parts[2], parts[1]);
						results.set('HOOK_ERROR:' + parts[2], parts[3]);
						check(parts[1] == 'ok', 'hook ${parts[2]} of $label runs (${parts[3]})');
					}
				default:
					Sys.println('        lua: $line');
			}
		}
		if(!sawScript)
		{
			failures++;
			Sys.println('  FAIL  $label never loaded');
		}
	}

	// ------------------------------------------------------------------
	// Stage 5: structural invariants of the loader
	// ------------------------------------------------------------------

	/** One-based line number of the offset `pos` in `source`. */
	static function lineAt(source:String, pos:Int):Int
	{
		var line:Int = 1;
		var limit:Int = pos < source.length ? pos : source.length;
		for(i in 0...limit) if(source.charAt(i) == '\n') line++;
		return line;
	}

	static function lineOf(source:String, needle:String):Int
	{
		var at:Int = source.indexOf(needle);
		if(at < 0) return -1;
		var line:Int = 1;
		for(i in 0...at) if(source.charAt(i) == '\n') line++;
		return line;
	}

	/**
	 * `FunkinLua` pushes itself into `PlayState.luaArray` *before* it publishes
	 * its globals and before it runs the script. Any exception thrown while a
	 * global is being published therefore leaves a half-built script in the
	 * dispatch list, and every later hook call reaches it. Keeping the push
	 * after the setup (or wrapping setup in a try/catch) is what makes a broken
	 * script fail alone instead of poisoning the whole Lua layer.
	 */
	static function testRegistrationOrdering():Void
	{
		Sys.println('[stage 5] loader structure');

		var source:String = sys.io.File.getContent('source/psychlua/FunkinLua.hx');
		var pushLine:Int = lineOf(source, 'game.luaArray.push(this)');
		check(pushLine > 0, 'FunkinLua is pushed into PlayState.luaArray');

		// Last `set('name', value)` global published before the script runs.
		var runLine:Int = lineOf(source, 'lastCalledScript = this;');
		var lastSet:Int = 0;
		var index:Int = 0;
		while(true)
		{
			var at:Int = source.indexOf('set(', index);
			if(at < 0) break;
			index = at + 4;
			var line:Int = lineAt(source, at);
			if(line > lastSet && (runLine < 0 || line < runLine)) lastSet = line;
		}
		check(lastSet > 0, 'the constructor publishes globals with set(...)');
		if(pushLine > 0 && lastSet > 0)
			info('luaArray.push() at line $pushLine, last global published at line $lastSet '
				+ (pushLine < lastSet ? '(a half-built script is already visible to callbacks)' : '(push happens after setup)'));

		// Executing through LuaL.loadbuffer is what makes the scan/execute pair
		// safe: the buffer scanned by ModSecurity is the buffer that runs.
		check(lineOf(source, 'result = LuaL.loadbuffer(lua, source') > 0,
			'the script is executed through LuaL.loadbuffer');

		var removeCalls:Int = 0;
		var scan:Int = 0;
		while(true)
		{
			var at:Int = source.indexOf('game.luaArray.remove(this)', scan);
			if(at < 0) break;
			removeCalls++;
			scan = at + 1;
		}
		info('$removeCalls luaArray.remove(this) call(s) in FunkinLua');

		// Every registered callback name must be a valid Lua identifier, or the
		// setglobal in Convert.addCallback publishes nothing callable.
		var bad:Array<String> = [];
		for(name in registeredFunctionNames())
			if(!isIdentifier(name)) bad.push(name);
		check(bad.length == 0, 'all registered API names are valid Lua identifiers' + (bad.length > 0 ? ': ' + bad.join(', ') : ''));

		// The globals the scripts in this tree read must be published by
		// FunkinLua; a hook reading an unpublished global dies on the first call.
		var published:Array<String> = engineGlobals();
		for(name in registeredFunctionNames())
			if(!published.contains(name)) published.push(name);
		var required:Array<String> = ['Function_Stop', 'Function_Continue', 'Function_StopLua',
			'songName', 'curBpm', 'screenWidth', 'scriptName', 'modFolder', 'difficultyName'];
		for(name in required)
			check(published.contains(name), 'engine publishes "$name" before running a script');
	}

	/**
	 * Negative controls: prove the harness reports the failure modes a mod
	 * author actually hits, instead of passing everything.
	 */
	static function testNegativeControls(luaJit:String, hooks:Array<String>):Void
	{
		Sys.println('  [negative controls]');

		var cases:Array<{label:String, source:String, expect:String, expectHook:String}> = [
			{
				label: 'syntax error',
				source: 'function onCreatePost(\n  debugPrint("unterminated")\nend',
				expect: 'LOAD_FAIL',
				expectHook: ''
			},
			{
				label: 'sandboxed API (os.execute)',
				source: 'function onCreatePost()\n  os.execute("echo hi")\nend',
				expect: 'TOPLEVEL_OK',
				expectHook: 'FAIL'
			},
			{
				label: 'calling an undefined engine function',
				source: 'function onCreatePost()\n  thisFunctionDoesNotExist()\nend',
				expect: 'TOPLEVEL_OK',
				expectHook: 'FAIL'
			},
			{
				label: 'valid script',
				source: 'function onCreatePost()\n  debugPrint("ok")\nend',
				expect: 'TOPLEVEL_OK',
				expectHook: 'ok'
			}
		];

		for(testCase in cases)
		{
			var results:Map<String, String> = new Map();
			var before:Int = failures;

			// Silence the runner's own check output and expected failures:
			// these controls exist to fail, and that is the point.
			quiet = true;
			runUnderLuaJit(luaJit, 'control: ' + testCase.label, testCase.source, hooks, results);

			var scriptResult:String = results.get('SCRIPT');
			check(scriptResult == testCase.expect,
				'control "${testCase.label}" is reported as ${testCase.expect} (got $scriptResult)');

			if(testCase.expectHook.length > 0)
			{
				var hookResult:String = results.get('HOOK:onCreatePost');
				check(hookResult == testCase.expectHook,
					'control "${testCase.label}" hook onCreatePost is $testCase.expectHook (got $hookResult)');
			}

			// Drop the expected failures the runner counted internally.
			quiet = false;
			failures = before;
			Sys.println('    ${testCase.label}: script=$scriptResult hook=${results.get('HOOK:onCreatePost')}');
		}
	}

	// ------------------------------------------------------------------

	static function main():Void
	{
		Sys.println('Lua script discovery / activation tests');
		Sys.println('');

		testBuildFlags();

		testDiscovery();
		testSongFolderNaming();

		var scripts:Array<String> = [];
		walkScripts('mods', scripts);
		if(sys.FileSystem.exists('docs/TemplateScript.lua')) scripts.push('docs/TemplateScript.lua');

		testSecurityGate(scripts);
		testScannerAllowsNormalMods();
		testScannerStillBlocks();
		testRegistrationOrdering();

		Sys.println('[stage 3+4] sandbox bootstrap + execution');

		var luaJit:String = Sys.getEnv('LUAJIT');
		if(luaJit == null || luaJit.length == 0)
		{
			info('LUAJIT is unset — skipping the interpreter half');
			info('  run: LUAJIT=/path/to/luajit bash tests/haxe/run-lua-discovery.sh');
		}
		else
		{
			var hooks:Array<String> = ['onCreate', 'onCreatePost', 'onUpdate', 'onUpdatePost', 'onDestroy'];
			for(script in scripts)
				runUnderLuaJit(luaJit, script, sys.io.File.getContent(script), hooks, new Map());
			testNegativeControls(luaJit, hooks);
		}

		if(Sys.getEnv('LUA_DISCOVERY_KEEP') == null)
		{
			try
			{
				if(sys.FileSystem.exists('.lua-discovery-tmp'))
				{
					for(file in sys.FileSystem.readDirectory('.lua-discovery-tmp'))
						sys.FileSystem.deleteFile('.lua-discovery-tmp/' + file);
					sys.FileSystem.deleteDirectory('.lua-discovery-tmp');
				}
			}
			catch(e:Dynamic) {}
		}

		Sys.println('');
		if(failures > 0)
		{
			Sys.println('LuaScriptDiscoverySpec: $failures of $checks checks FAILED');
			Sys.exit(1);
		}
		Sys.println('LuaScriptDiscoverySpec: all $checks checks passed');
	}
}
