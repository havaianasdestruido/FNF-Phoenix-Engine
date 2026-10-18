package backend;

using StringTools;

/** A source-level sandbox rule. */
typedef ScriptSecurityRule =
{
	var id:String;
	var description:String;
	var pattern:EReg;
}

/** One suspicious source location found before a softmod script is run. */
typedef ScriptSecurityFinding =
{
	var line:Int;
	var rule:String;
	var description:String;
	var snippet:String;
}

/**
 * Dependency-free source scanner used by ModSecurity.
 *
 * This is deliberately separate from the game/runtime integration so its
 * matching and line-number behaviour can be tested with plain `haxe --interp`.
 * It is one layer of the sandbox, not a claim that text matching alone is a
 * security boundary; Lua library replacement and interpreter restrictions are
 * applied by ModSecurity's runtime integration as well.
 */
class ScriptSecurityScanner
{
	public static final LUA_RULES:Array<ScriptSecurityRule> = [
		{
			id: 'lua.os',
			description: 'Lua os library access',
			pattern: ~/\bos\s*(?:\.|\[)/i
		},
		{
			id: 'lua.io',
			description: 'Lua io library access',
			pattern: ~/\bio\s*(?:\.|\[)/i
		},
		{
			id: 'lua.package',
			description: 'Lua module/package loading',
			pattern: ~/\b(?:package\s*(?:\.|\[)|require\s*\(|module\s*\()/i
		},
		{
			id: 'lua.dynamic-code',
			description: 'Lua dynamic code or file execution',
			pattern: ~/\b(?:dofile|loadfile|loadstring|load)\s*\(/i
		},
		{
			id: 'lua.native',
			description: 'Lua debug/JIT/native interface access',
			pattern: ~/\b(?:debug|ffi|jit)\s*(?:\.|\[|\()/i
		}
	];

	public static final PYTHON_RULES:Array<ScriptSecurityRule> = [
		{
			id: 'python.dangerous-import',
			description: 'Python operating-system, process, file, or network module import',
			pattern: ~/^\s*(?:from|import)\s+[^#]*\b(?:os|sys|io|pathlib|shutil|subprocess|socket|http|urllib|requests|ftplib|ctypes|multiprocessing)\b/i
		},
		{
			id: 'python.dangerous-module',
			description: 'Python operating-system, process, file, or network module access',
			pattern: ~/\b(?:os|sys|io|pathlib|shutil|subprocess|socket|http|urllib|requests|ftplib|ctypes|multiprocessing)\s*\./i
		},
		{
			id: 'python.dynamic-code',
			description: 'Python dynamic code, import, file, or console access',
			pattern: ~/\b(?:open|exec|eval|compile|__import__|input)\b/i
		}
	];

	public static final HAXE_RULES:Array<ScriptSecurityRule> = [
		{
			id: 'haxe.process',
			description: 'Haxe process execution or process exit',
			pattern: ~/\b(?:Sys\s*\.\s*(?:command|exit)|sys\s*\.\s*io\s*\.\s*Process)\b/i
		},
		{
			id: 'haxe.filesystem',
			description: 'Haxe filesystem access',
			pattern: ~/\b(?:sys\s*\.\s*io\s*\.\s*File|sys\s*\.\s*FileSystem)\b/i
		},
		{
			id: 'haxe.native',
			description: 'Haxe native library or application access',
			pattern: ~/\b(?:cpp\s*\.\s*Lib\s*\.\s*load|neko\s*\.\s*Lib\s*\.\s*load|openfl\s*\.\s*Lib\s*\.\s*application|lime\s*\.\s*(?:system|app))\b/i
		},
		{
			id: 'haxe.reflection',
			description: 'Haxe dynamic class resolution or method invocation',
			pattern: ~/\b(?:Type\s*\.\s*(?:resolveClass|resolveEnum|createInstance|createEmptyInstance)|Reflect\s*\.\s*callMethod)\b/i
		},
		{
			id: 'haxe.network',
			description: 'Haxe/OpenFL network access',
			pattern: ~/\b(?:haxe\s*\.\s*Http|openfl\s*\.\s*net|lime\s*\.\s*net)\b/i
		}
	];

	public static final COMMON_RULES:Array<ScriptSecurityRule> = [
		{
			id: 'engine.file-read',
			description: 'engine file/directory read API',
			pattern: ~/\b(?:getTextFromFile|checkFileExists|directoryFileList)\b/i
		},
		{
			id: 'engine.file-write',
			description: 'engine file write/delete API',
			pattern: ~/\b(?:saveFile|deleteFile)\b/i
		},
		{
			id: 'engine.script-loader',
			description: 'dynamic softmod script loading',
			pattern: ~/\b(?:addLuaScript|addPythonScript|addScript)\b/i
		},
		{
			id: 'engine.native-class',
			description: 'engine reflection access to a privileged class',
			pattern: ~/\b(?:getPropertyFromClass|setPropertyFromClass)\s*\(\s*["'](?:Sys|Type|Reflect|sys\.|cpp\.|neko\.|hl\.|java\.|objc\.|haxe\.Http|backend\.ModSecurity|backend\.Mods|psychlua\.|openfl\.(?:Lib|net|filesystem)|lime\.(?:system|app|net)|utils\.PlatformUtil|system\.|slushithings\.|android\.|ios\.|mac\.)/i
		},
		{
			id: 'process.shell',
			description: 'shell, command interpreter, or downloader invocation',
			pattern: ~/(?:\bpython(?:3(?:\.\d+)*)?\s+-[A-Za-z]*c\b|\bpy\s+-[A-Za-z]*c\b|\bcmd(?:\.exe)?\s*\/c\b|\b(?:powershell|pwsh)(?:\.exe)?\b|\b(?:bash|sh)\s+-c\b|\/bin\/(?:bash|sh)\b|\b(?:curl|wget)(?:\.exe)?\b)/i
		},
		{
			id: 'network.url',
			description: 'network or file URL',
			pattern: ~/(?:https?|ftp|file):\/\//i
		},
		{
			id: 'network.api',
			description: 'network client API',
			pattern: ~/(?:\b(?:socket|requests?|urllib|ftplib)\s*(?:\.|\[|\()|\brequire\s*\(\s*["'](?:socket|http|https|ssl|ftp))/i
		}
	];

	/**
	 * Scan source and return every non-allowlisted finding with one-based lines.
	 * `language` is `lua`, `python`, or `haxe` (aliases `py`, `hx`, and
	 * `hscript` are accepted). Comment-only lines are ignored so documentation
	 * does not disable a mod; suspicious strings on executable lines are not.
	 */
	public static function scan(source:String, language:String, ?allowlist:Array<String>):Array<ScriptSecurityFinding>
	{
		var findings:Array<ScriptSecurityFinding> = [];
		if(source == null) return findings;
		if(allowlist == null) allowlist = [];

		var normalizedLanguage:String = language == null ? '' : language.toLowerCase();
		var rules:Array<ScriptSecurityRule> = switch(normalizedLanguage)
		{
			case 'lua': LUA_RULES;
			case 'python' | 'py': PYTHON_RULES;
			case 'haxe' | 'hx' | 'hscript': HAXE_RULES;
			default: [];
		};

		var lines:Array<String> = source.split('\n');
		for(i in 0...lines.length)
		{
			var line:String = lines[i];
			if(line.endsWith('\r')) line = line.substr(0, line.length - 1);
			if(isCommentOnly(line, normalizedLanguage)) continue;

			matchRules(line, i + 1, rules, allowlist, findings);
			matchRules(line, i + 1, COMMON_RULES, allowlist, findings);
		}
		return findings;
	}

	public static function isAllowed(rule:String, allowlist:Array<String>):Bool
	{
		if(allowlist == null || rule == null) return false;
		for(entry in allowlist)
			if(entry != null && entry.trim() == rule) return true;
		return false;
	}

	public static function descriptionFor(ruleId:String):String
	{
		for(rules in [LUA_RULES, PYTHON_RULES, HAXE_RULES, COMMON_RULES])
			for(rule in rules)
				if(rule.id == ruleId) return rule.description;
		return 'blocked script capability';
	}

	static function matchRules(line:String, lineNumber:Int, rules:Array<ScriptSecurityRule>, allowlist:Array<String>,
		findings:Array<ScriptSecurityFinding>):Void
	{
		for(rule in rules)
		{
			if(isAllowed(rule.id, allowlist) || !rule.pattern.match(line)) continue;

			// A line can be scanned by more than one language pass (Lua files that
			// contain HScript), so keep rule/line pairs unique.
			var duplicate:Bool = false;
			for(finding in findings)
			{
				if(finding.line == lineNumber && finding.rule == rule.id)
				{
					duplicate = true;
					break;
				}
			}
			if(!duplicate)
			{
				findings.push({
					line: lineNumber,
					rule: rule.id,
					description: rule.description,
					snippet: trimSnippet(line)
				});
			}
		}
	}

	static function isCommentOnly(line:String, language:String):Bool
	{
		var trimmed:String = line.ltrim();
		if(trimmed.length == 0) return true;
		return switch(language)
		{
			case 'lua':
				if(!trimmed.startsWith('--')) false;
				else if(trimmed.startsWith('--[[') && trimmed.indexOf(']]') >= 0)
					trimmed.substr(trimmed.indexOf(']]') + 2).trim().length == 0;
				else true;
			case 'python' | 'py': trimmed.startsWith('#');
			case 'haxe' | 'hx' | 'hscript':
				if(trimmed.startsWith('//') || trimmed.startsWith('*')) true;
				else if(trimmed.startsWith('/*') && trimmed.indexOf('*/') >= 0)
					trimmed.substr(trimmed.indexOf('*/') + 2).trim().length == 0;
				else trimmed.startsWith('/*');
			default: false;
		};
	}

	static function trimSnippet(line:String):String
	{
		var snippet:String = line.trim().split('\t').join(' ');
		return snippet.length > 160 ? snippet.substr(0, 160) + '...' : snippet;
	}
}
