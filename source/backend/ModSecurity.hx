package backend;

import backend.ScriptSecurityScanner.ScriptSecurityFinding;

using StringTools;

private typedef ModSandboxConfig =
{
	var enabled:Bool;
	var allowlist:Array<String>;
}

/** Security decision made before a Lua/Python softmod script is started. */
typedef ModSecurityCheck =
{
	var scriptName:String;
	var displayPath:String;
	var language:String;
	var softmod:Bool;
	var sandboxed:Bool;
	var optedOut:Bool;
	var modFolder:Null<String>;
	var modName:String;
	var allowlist:Array<String>;
	var findings:Array<ScriptSecurityFinding>;
}

/**
 * Basic defence-in-depth for untrusted Lua and Python softmod scripts.
 *
 * A source denylist stops suspicious scripts before any top-level code runs.
 * The script runtimes then apply a second layer: dangerous Lua libraries are
 * replaced, Python cannot resolve host classes, privileged engine callbacks
 * are guarded, and embedded HScript is scanned separately.
 *
 * This is intentionally described as a basic sandbox. It reduces the attack
 * surface of accidental or straightforward malicious scripts; it is not an
 * OS/process isolation boundary.
 *
 * Pattern-based policy inspired by Psych Plus's ModSecurity design:
 * https://github.com/Psych-Plus-Team/FNF-PlusEngine
 */
@:unreflective
class ModSecurity
{
	public static inline final LOOSE_MOD_NAME:String = '<loose mods>';

	static final BLOCKED_CALLBACK_RULES:Map<String, String> = [
		'saveFile' => 'engine.file-write',
		'deleteFile' => 'engine.file-write',
		'getTextFromFile' => 'engine.file-read',
		'checkFileExists' => 'engine.file-read',
		'directoryFileList' => 'engine.file-read',
		'addLuaScript' => 'engine.script-loader'
	];

	static var configCache:Map<String, ModSandboxConfig> = [];
	static var warnedOptOutMods:Map<String, Bool> = [];

	/** Inspect one script. Findings mean the caller must not create/execute it. */
	public static function checkScript(scriptName:String, source:String, language:String):ModSecurityCheck
	{
		var normalizedPath:String = normalizePath(scriptName);
		var owner = findModOwner(normalizedPath);
		var config:ModSandboxConfig = owner.softmod ? getConfig(owner.folder) : {enabled: false, allowlist: []};
		var sandboxed:Bool = owner.softmod && config.enabled;
		var findings:Array<ScriptSecurityFinding> = [];

		if(sandboxed)
		{
			if(source == null)
			{
				findings.push({
					line: 1,
					rule: 'security.unreadable',
					description: 'script source could not be read for security scanning',
					snippet: ''
				});
			}
			else
			{
				findings = ScriptSecurityScanner.scan(source, language, config.allowlist);

				// Lua can bridge to HScript. Scan the same physical source for the
				// concrete Haxe operation when a bridge is present, while allowing
				// ordinary runHaxeCode usage that only manipulates game objects.
				if(language != null && language.toLowerCase() == 'lua'
					&& ~/\b(?:runHaxeCode|runHaxeFunction|addHaxeLibrary)\b/.match(source))
				{
					mergeFindings(findings, ScriptSecurityScanner.scan(source, 'haxe', config.allowlist));
				}

				if(source.indexOf(String.fromCharCode(0)) != -1
					&& !ScriptSecurityScanner.isAllowed('security.binary-source', config.allowlist))
				{
					findings.push({
						line: 1,
						rule: 'security.binary-source',
						description: 'NUL byte in script source',
						snippet: ''
					});
				}
			}
		}

		return {
			scriptName: scriptName == null ? '' : scriptName,
			displayPath: displayPath(normalizedPath, owner.folder),
			language: language == null ? '' : language,
			softmod: owner.softmod,
			sandboxed: sandboxed,
			optedOut: owner.softmod && !config.enabled,
			modFolder: owner.folder,
			modName: owner.folder == null ? (owner.softmod ? LOOSE_MOD_NAME : '<engine>') : owner.folder,
			allowlist: config.allowlist.copy(),
			findings: findings
		};
	}

	/**
	 * Emit the user-facing warning/block report. `sink` is normally the
	 * PlayState debug console; trace output is always produced as a durable log.
	 */
	public static function report(check:ModSecurityCheck, ?sink:String->Void):Void
	{
		if(check == null) return;

		if(check.optedOut && !warnedOptOutMods.exists(check.modName))
		{
			warnedOptOutMods.set(check.modName, true);
			emit('[ModSecurity] WARNING: mod "${check.modName}" opted out of script sandboxing in pack.json. '
				+ 'Its Lua/Python scripts run with full engine privileges.', sink);
		}

		if(check.findings.length == 0) return;
		var findingSuffix:String = check.findings.length == 1 ? '' : 's';
		emit('[ModSecurity] BLOCKED ${check.language} script "${check.displayPath}" from mod "${check.modName}" '
			+ 'before execution (${check.findings.length} security finding$findingSuffix).', sink);
		for(finding in check.findings)
		{
			var snippet:String = finding.snippet.length > 0 ? ' | ${finding.snippet}' : '';
			emit('[ModSecurity] mod="${check.modName}" script="${check.displayPath}" line=${finding.line} '
				+ 'rule=${finding.rule}: ${finding.description}$snippet', sink);
		}
	}

	public static function formatRuntimeBlock(modName:String, scriptName:String, capability:String, ?line:Int = 0):String
	{
		var owner:String = modName == null || modName.length == 0 ? LOOSE_MOD_NAME : modName;
		var where:String = line > 0 ? ' line=$line' : '';
		return '[ModSecurity] BLOCKED runtime call in mod="$owner" script="${displayPath(normalizePath(scriptName), modName)}"$where: $capability';
	}

	public static function runtimeRuleForCallback(callbackName:String):Null<String>
		return BLOCKED_CALLBACK_RULES.get(callbackName);

	public static inline function isRuleAllowed(rule:String, allowlist:Array<String>):Bool
		return ScriptSecurityScanner.isAllowed(rule, allowlist);

	public static function isRuntimeCallbackBlocked(callbackName:String, sandboxed:Bool, allowlist:Array<String>):Bool
	{
		if(!sandboxed) return false;
		var rule:String = BLOCKED_CALLBACK_RULES.get(callbackName);
		return rule != null && !isRuleAllowed(rule, allowlist);
	}

	/** Classes that reflection callbacks must never expose to sandboxed mods. */
	public static function isPrivilegedClass(className:String):Bool
	{
		if(className == null) return false;
		var value:String = className.trim().toLowerCase();
		if(value.length == 0) return false;

		for(prefix in [
			'sys.', 'cpp.', 'neko.', 'hl.', 'java.', 'objc.', 'backend.modsecurity', 'backend.mods',
			'psychlua.', 'haxe.http', 'openfl.lib', 'openfl.net', 'openfl.filesystem', 'lime.system',
			'lime.app', 'lime.net', 'utils.platformutil', 'system.', 'slushithings.', 'android.', 'ios.', 'mac.'
		])
		{
			if(value == prefix || value.startsWith(prefix)) return true;
		}
		return value == 'sys' || value == 'type' || value == 'reflect' || value == 'main'
			|| value == 'modsecurity' || value == 'mods';
	}

	/**
	 * Lua code installed immediately after openlibs(). Each non-allowlisted
	 * standard-library category becomes a sealed proxy whose calls fail before
	 * reaching LuaJIT/FFI/OS code. package.loaded is replaced too so require()
	 * cannot recover a reference after only one category was allowlisted.
	 */
	public static function luaBootstrap(allowlist:Array<String>):String
	{
		var out:StringBuf = new StringBuf();
		out.add("local function __phoenix_block(name)\n");
		out.add("  return function(...) error('[ModSecurity] blocked Lua call: ' .. name, 2) end\n");
		out.add("end\n");
		out.add("local function __phoenix_proxy(name)\n");
		out.add("  return setmetatable({}, {\n");
		out.add("    __index = function(_, key) return __phoenix_block(name .. '.' .. tostring(key)) end,\n");
		out.add("    __newindex = function() error('[ModSecurity] blocked Lua library mutation: ' .. name, 2) end,\n");
		out.add("    __metatable = false\n");
		out.add("  })\n");
		out.add("end\n");

		if(!isRuleAllowed('lua.os', allowlist))
		{
			out.add("os = __phoenix_proxy('os')\n");
			out.add("if package and package.loaded then package.loaded.os = os end\n");
		}
		if(!isRuleAllowed('lua.io', allowlist))
		{
			out.add("io = __phoenix_proxy('io')\n");
			out.add("if package and package.loaded then package.loaded.io = io end\n");
		}
		if(!isRuleAllowed('lua.native', allowlist))
		{
			out.add("debug = __phoenix_proxy('debug')\n");
			out.add("ffi = __phoenix_proxy('ffi')\n");
			out.add("jit = __phoenix_proxy('jit')\n");
			out.add("if package and package.loaded then package.loaded.debug = debug; package.loaded.ffi = ffi; package.loaded.jit = jit end\n");
			out.add("if package then package.loadlib = __phoenix_block('package.loadlib'); package.cpath = '' end\n");
			out.add("if package and package.loaders then package.loaders[3] = __phoenix_block('package C loader'); package.loaders[4] = __phoenix_block('package C root loader') end\n");
		}
		if(!isRuleAllowed('lua.dynamic-code', allowlist))
		{
			for(name in ['dofile', 'loadfile', 'loadstring', 'load'])
				out.add('$name = __phoenix_block("$name")\n');
		}
		if(!isRuleAllowed('lua.package', allowlist))
		{
			out.add("require = __phoenix_block('require')\n");
			out.add("module = __phoenix_block('module')\n");
			out.add("package = __phoenix_proxy('package')\n");
		}
		return out.toString();
	}

	/** Drop cached pack.json decisions (mainly useful after an in-process reload). */
	public static function clearCache():Void
	{
		configCache.clear();
		warnedOptOutMods.clear();
	}

	static function getConfig(folder:Null<String>):ModSandboxConfig
	{
		if(folder == null) return {enabled: true, allowlist: []}; // loose files in mods/
		if(configCache.exists(folder))
		{
			var cached:ModSandboxConfig = configCache.get(folder);
			return {enabled: cached.enabled, allowlist: cached.allowlist.copy()};
		}

		var enabled:Bool = true;
		var allowlist:Array<String> = [];
		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack(folder);
		if(pack != null)
		{
			if(Reflect.field(pack, 'scriptSandbox') == false || Reflect.field(pack, 'allowUnsafeScripts') == true)
				enabled = false;
			appendAllowlist(allowlist, Reflect.field(pack, 'scriptSandboxAllowlist'));

			// Also accept a grouped form for pack authors that keep metadata tidy:
			// "scriptSecurity": {"enabled": true, "allowlist": [...]}
			var grouped:Dynamic = Reflect.field(pack, 'scriptSecurity');
			if(grouped != null)
			{
				if(Reflect.field(grouped, 'enabled') == false) enabled = false;
				appendAllowlist(allowlist, Reflect.field(grouped, 'allowlist'));
			}
		}
		#end

		var config:ModSandboxConfig = {enabled: enabled, allowlist: allowlist};
		configCache.set(folder, config);
		return {enabled: enabled, allowlist: allowlist.copy()};
	}

	static function appendAllowlist(output:Array<String>, raw:Dynamic):Void
	{
		if(raw == null || !Std.isOfType(raw, Array)) return;
		for(value in (cast raw:Array<Dynamic>))
		{
			if(!Std.isOfType(value, String)) continue;
			var rule:String = (cast value:String).trim();
			if(rule.length > 0 && !output.contains(rule)) output.push(rule);
		}
	}

	static function mergeFindings(output:Array<ScriptSecurityFinding>, extra:Array<ScriptSecurityFinding>):Void
	{
		for(candidate in extra)
		{
			var duplicate:Bool = false;
			for(existing in output)
			{
				if(existing.line == candidate.line && existing.rule == candidate.rule)
				{
					duplicate = true;
					break;
				}
			}
			if(!duplicate) output.push(candidate);
		}
	}

	static function findModOwner(path:String):{softmod:Bool, folder:Null<String>}
	{
		var lower:String = path.toLowerCase();
		var start:Int = -1;
		if(lower.startsWith('mods/')) start = 5;
		else
		{
			var marker:Int = lower.indexOf('/mods/');
			if(marker >= 0) start = marker + 6;
		}
		if(start < 0 || start > path.length) return {softmod: false, folder: null};

		var remainder:String = path.substr(start);
		if(remainder.length == 0) return {softmod: true, folder: null};
		var slash:Int = remainder.indexOf('/');
		if(slash < 0) return {softmod: true, folder: null};

		var first:String = remainder.substr(0, slash);
		var firstLower:String = first.toLowerCase();
		// These are the recognised loose-content folders, not mod names.
		for(reserved in [
			'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders',
			'videos', 'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
		])
			if(firstLower == reserved) return {softmod: true, folder: null};
		return {softmod: true, folder: first};
	}

	static function normalizePath(path:String):String
	{
		if(path == null) return '';
		var normalized:String = path.split('\\').join('/');
		while(normalized.startsWith('./')) normalized = normalized.substr(2);
		while(normalized.indexOf('//') != -1) normalized = normalized.split('//').join('/');
		return normalized;
	}

	static function displayPath(path:String, folder:Null<String>):String
	{
		if(path == null || path.length == 0) return '<inline script>';
		var lower:String = path.toLowerCase();
		var marker:String = folder == null ? 'mods/' : 'mods/' + folder.toLowerCase() + '/';
		var index:Int = lower.indexOf(marker);
		return index >= 0 ? path.substr(index + marker.length) : path;
	}

	static function emit(message:String, sink:Null<String->Void>):Void
	{
		trace(message);
		if(sink != null) sink(message);
	}
}
