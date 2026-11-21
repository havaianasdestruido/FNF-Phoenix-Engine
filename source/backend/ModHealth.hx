package backend;

using StringTools;

/** One script a mod's sandbox refused, and the rules that stopped it. */
typedef BlockedScript =
{
	/** `lua`, `python`, `haxe` for a script stopped before it ran; `runtime` for a call blocked inside it. */
	var language:String;
	/** Script path as the panel shows it. */
	var script:String;
	/** Rule ids (`lua.os`, `engine.file-write`, …). */
	var rules:Array<String>;
	/** How many times the same script hit the same guard (a reload can hit it again). */
	var count:Int;
}

/** The most recent failure of one script to load. */
typedef ScriptError =
{
	var script:String;
	var message:String;
}

/** A mod's recorded problems, in the severity order the Mods menu shows them. */
typedef ModHealthReport =
{
	var folder:String;
	/** `NO_PROBLEMS`, `MISSING_ASSETS` or `BROKEN`. */
	var severity:Int;
	/** The most recent script load failure, or null. */
	var loadError:Null<ScriptError>;
	/** Why `pack.json` could not be used, or null when it parses. */
	var invalidPack:Null<String>;
	/** Scripts the sandbox refused, at most `ModHealth.MAX_BLOCKED_SCRIPTS` of them. */
	var blocked:Array<BlockedScript>;
	/** Distinct assets of this mod that did not load. */
	var missingAssets:Int;
	/** Up to `ModHealth.MAX_LISTED_ASSETS` of those assets' keys. */
	var missingList:Array<String>;
}

/**
 * What went wrong with one mod, recorded while it runs, so the Mods menu can
 * answer "why did it break?" without asking the player to read a log (§19).
 *
 * Four things are collected per mod folder, which are the four ways a broken
 * Psych-style mod actually fails:
 *
 * - **last load error** — a Lua/Python/HScript file that threw while loading,
 *   recorded from `psychlua.FunkinLua`, `PythonScript`, `HScript` and `HaxeScript`;
 * - **invalid `pack.json`** — a manifest that cannot be parsed or is not an
 *   object, recorded by `Mods.getPack()`;
 * - **blocked script rule** — a script the §6 sandbox refused before it ran
 *   (`ModSecurity.report()`), or a blocked runtime call inside a script that did
 *   load (the runtimes' `reportSecurityRuntime()`);
 * - **missing assets** — images, sounds and atlases that resolved to a mod folder
 *   and then did not load, recorded by `backend.Paths`.
 *
 * Recording is cheap and never throws. Every list is capped and every string is
 * flattened to one bounded line, so a mod that fails in a loop cannot grow this
 * module without bound and the menu can read it while drawing. Nothing here
 * touches the filesystem, so the module also runs in the interpreter specs and on
 * targets without one.
 *
 * Text written by a mod (a script path, an interpreter message) is never handed
 * out raw: `lines()` returns it as a single capped line, like the Mod Info panel
 * already does with a mod's own name.
 */
class ModHealth
{
	/** Nothing recorded: the mod loads, its manifest parses and its assets resolve. */
	public static inline final NO_PROBLEMS:Int = 0;

	/** Only assets are missing: the mod runs, but some of its content is not on disk. */
	public static inline final MISSING_ASSETS:Int = 1;

	/** A script failed to load, its `pack.json` is invalid, or the sandbox blocked it. */
	public static inline final BROKEN:Int = 2;

	/** Longest chunk of mod-written text kept, in characters. */
	static inline final MAX_TEXT:Int = 160;

	/** Longest script path or asset key kept, in characters. */
	static inline final MAX_KEY:Int = 96;

	/** Longest rule id kept. Real ids are shorter (`python.dangerous-import`). */
	static inline final MAX_RULE:Int = 40;

	/** Blocked scripts remembered per mod; the rest are dropped, not counted. */
	public static inline final MAX_BLOCKED_SCRIPTS:Int = 8;

	/** Missing asset keys remembered per mod, so the list stays bounded. */
	public static inline final MAX_LISTED_ASSETS:Int = 12;

	/** Asset keys spelled out on a report line before "+N more". */
	static inline final MAX_SHOWN_ASSETS:Int = 2;

	/**
	 * Folders directly under `mods/` that hold loose shared content instead of a
	 * mod. Mirrors `ModPathPolicy.RESERVED_MOD_FOLDERS` (a spec keeps them in
	 * sync); it is duplicated here because `backend/Paths.hx` records missing
	 * assets on the load path and must not depend on the importer.
	 */
	public static final SHARED_FOLDERS:Array<String> = [
		'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds',
		'shaders', 'videos', 'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
	];

	/** Folder -> why its `pack.json` could not be used. */
	static var invalidPacks:Map<String, String> = [];

	/** Folder -> its most recent script load failure. */
	static var loadErrors:Map<String, ScriptError> = [];

	/** Folder -> `language/script` -> what the sandbox refused. */
	static var blockedScripts:Map<String, Map<String, BlockedScript>> = [];

	/** Folder -> every distinct missing asset key, so the count stays exact past the listing cap. */
	static var missingSeen:Map<String, Map<String, Bool>> = [];

	/** Folder -> the first `MAX_LISTED_ASSETS` missing keys, in the order they failed. */
	static var missingListed:Map<String, Array<String>> = [];

	// -- Recording ---------------------------------------------------------------

	/**
	 * Records that a mod's `pack.json` exists but could not be used.
	 *
	 * @param folder mod folder under `mods/`
	 * @param reason what the parser or the shape check complained about
	 */
	public static function recordInvalidPack(?folder:String, reason:String):Void
	{
		if(!isModFolder(folder)) return;
		var text:String = sanitize(reason, MAX_TEXT);
		if(text.length == 0) text = 'the file could not be read';
		invalidPacks.set(folder, text);
	}

	/**
	 * Records the failure of one script to load. Only the most recent failure per
	 * mod is kept, which is what "last load error" means in the menu.
	 *
	 * @param folder  mod folder the script belongs to; derived from `script` when null
	 * @param script  the script path, as the runtime knows it
	 * @param message the interpreter message
	 */
	public static function recordLoadError(?folder:String, script:String, message:String):Void
	{
		// A runtime that lost track of the owner still names the file: the path
		// under `mods/<folder>/` is enough to attribute it.
		if(!isModFolder(folder)) folder = folderForPath(script);
		if(!isModFolder(folder)) return;

		loadErrors.set(folder, {
			script: scriptLabel(sanitize(script, MAX_KEY)),
			message: sanitize(message, MAX_TEXT)
		});
	}

	/**
	 * Records a script the sandbox refused before it ran, with the rule ids that
	 * stopped it (§6). The same script seen twice only gains rules, so a reload
	 * cannot grow the list; a mod keeps at most `MAX_BLOCKED_SCRIPTS` entries.
	 *
	 * @param folder   mod folder the script belongs to; derived from `script` when null
	 * @param script   the script path as the panel shows it
	 * @param language `lua`, `python` or `haxe`
	 * @param findings scanner findings for that script
	 */
	public static function recordSecurity(?folder:String, script:String, language:String, findings:Array<{rule:String}>):Void
	{
		if(findings == null || findings.length == 0) return;

		var rules:Array<String> = [];
		for(finding in findings)
		{
			if(finding == null || finding.rule == null) continue;
			var rule:String = sanitize(finding.rule, MAX_RULE);
			if(rule.length > 0 && !rules.contains(rule)) rules.push(rule);
		}
		recordRules(folder, script, language, rules);
	}

	/**
	 * Records a runtime guard that refused a call inside a script that did load
	 * (a sandboxed mod reaching for a blocked engine callback, §6). The sibling of
	 * `recordSecurity()`: the script runs, but part of what it does is dropped.
	 *
	 * @param folder     mod folder the script belongs to
	 * @param script     the script path, as the runtime knows it
	 * @param capability the `[ModSecurity]` message that was logged
	 */
	public static function recordRuntimeBlock(?folder:String, script:String, capability:String):Void
	{
		var text:String = sanitize(capability, MAX_TEXT);
		if(text.length == 0) return;
		recordRules(folder, script, 'runtime', [runtimeRule(text)]);
	}

	/**
	 * Records an asset that did not load. The owning mod comes from the resolved
	 * path, so engine assets and loose shared content are ignored. Only distinct
	 * keys are counted: retrying a load does not inflate the number.
	 *
	 * @param path resolved asset path (`mods/<folder>/images/x.png`, …)
	 */
	public static function recordMissingAsset(path:String):Void
	{
		var folder:Null<String> = folderForPath(path);
		if(folder == null) return;

		var key:String = withinFolder(folder, path);
		if(key.length == 0) key = path;
		key = sanitize(key, MAX_KEY);

		var seen:Map<String, Bool> = missingSeen.get(folder);
		if(seen == null)
		{
			seen = [];
			missingSeen.set(folder, seen);
		}
		if(seen.exists(key)) return;
		seen.set(key, true);

		var listed:Array<String> = missingListed.get(folder);
		if(listed == null)
		{
			listed = [];
			missingListed.set(folder, listed);
		}
		if(listed.length < MAX_LISTED_ASSETS) listed.push(key);
	}

	/** Folder -> `language/script` entry, adding rules to an existing one. */
	static function recordRules(?folder:String, script:String, language:String, rules:Array<String>):Void
	{
		if(rules.length == 0) return;
		if(!isModFolder(folder)) folder = folderForPath(script);
		if(!isModFolder(folder)) return;

		var entries:Map<String, BlockedScript> = blockedScripts.get(folder);
		if(entries == null)
		{
			entries = [];
			blockedScripts.set(folder, entries);
		}

		var shownScript:String = scriptLabel(sanitize(script, MAX_KEY));
		var shownLanguage:String = sanitize(language, 12);
		var key:String = shownLanguage + '/' + shownScript;
		var existing:BlockedScript = entries.get(key);
		if(existing != null)
		{
			for(rule in rules) if(!existing.rules.contains(rule)) existing.rules.push(rule);
			existing.count++;
			return;
		}
		if(countKeys(entries) >= MAX_BLOCKED_SCRIPTS) return;

		entries.set(key, {
			language: shownLanguage.length > 0 ? shownLanguage : 'script',
			script: shownScript,
			rules: rules,
			count: 1
		});
	}

	// -- Reading -----------------------------------------------------------------

	/** Whether nothing at all is recorded for this mod. */
	public static function isHealthy(folder:String):Bool
		return severity(folder) == NO_PROBLEMS;

	/** How bad this mod's recorded problems are (`NO_PROBLEMS`, `MISSING_ASSETS` or `BROKEN`). */
	public static function severity(folder:String):Int
	{
		if(!isModFolder(folder)) return NO_PROBLEMS;
		if(invalidPacks.exists(folder) || loadErrors.exists(folder) || blockedScripts.exists(folder)) return BROKEN;
		return missingAssets(folder) > 0 ? MISSING_ASSETS : NO_PROBLEMS;
	}

	/**
	 * Everything recorded about one mod, ready for the menu. The returned lists are
	 * copies, so a caller cannot change what was recorded.
	 */
	public static function report(?folder:String):ModHealthReport
	{
		var report:ModHealthReport = {
			folder: folder == null ? '' : folder,
			severity: NO_PROBLEMS,
			loadError: null,
			invalidPack: null,
			blocked: [],
			missingAssets: 0,
			missingList: []
		};
		if(!isModFolder(folder)) return report;

		report.severity = severity(folder);
		report.loadError = loadErrors.get(folder);
		report.invalidPack = invalidPacks.get(folder);
		report.missingAssets = missingAssets(folder);

		var listed:Array<String> = missingListed.get(folder);
		if(listed != null) report.missingList = listed.copy();

		var entries:Array<BlockedScript> = blockedFor(folder);
		entries.sort(function(a:BlockedScript, b:BlockedScript):Int
		{
			// Load-time blocks first, then runtime guards, each group by language
			// and path: the order must not depend on how a Map happens to iterate.
			var aRuntime:Bool = a.language == 'runtime';
			var bRuntime:Bool = b.language == 'runtime';
			if(aRuntime != bRuntime) return aRuntime ? 1 : -1;
			if(a.language != b.language) return a.language < b.language ? -1 : 1;
			return a.script < b.script ? -1 : (a.script > b.script ? 1 : 0);
		});
		report.blocked = entries;
		return report;
	}

	/** Distinct assets of this mod that failed to load. */
	public static function missingAssets(folder:String):Int
	{
		if(!isModFolder(folder)) return 0;
		var seen:Map<String, Bool> = missingSeen.get(folder);
		return seen == null ? 0 : countKeys(seen);
	}

	/** Why this mod's `pack.json` could not be used, or null when it parses. */
	public static function invalidPackReason(folder:String):Null<String>
		return isModFolder(folder) ? invalidPacks.get(folder) : null;

	/** The most recent script load failure of this mod, or null. */
	public static function lastLoadError(folder:String):Null<ScriptError>
		return isModFolder(folder) ? loadErrors.get(folder) : null;

	/** How many scripts of this mod the sandbox refused. */
	public static function blockedCount(folder:String):Int
		return blockedFor(folder).length;

	/** Scripts of this mod the sandbox refused, one entry per language and path. */
	public static function blockedFor(folder:String):Array<BlockedScript>
	{
		var result:Array<BlockedScript> = [];
		if(!isModFolder(folder)) return result;
		var entries:Map<String, BlockedScript> = blockedScripts.get(folder);
		if(entries == null) return result;
		for(key in entries.keys()) result.push(entries.get(key));
		return result;
	}

	/**
	 * One short line for the Mods menu, built from counts only: it never repeats
	 * text written by the mod, so it cannot be used to write into the menu.
	 */
	public static function summary(folder:String):String
	{
		if(isHealthy(folder)) return 'No problems detected';

		var parts:Array<String> = [];
		var report:ModHealthReport = report(folder);
		if(report.loadError != null) parts.push('script error');
		if(report.invalidPack != null) parts.push('invalid pack.json');
		if(report.blocked.length > 0) parts.push(plural(report.blocked.length, 'blocked script'));
		if(report.missingAssets > 0) parts.push(plural(report.missingAssets, 'missing asset'));
		return 'PROBLEMS: ' + parts.join(', ');
	}

	/**
	 * Everything known about one mod, one line per problem, for the Mod Info panel.
	 * Each line is engine wording plus at most one bounded, flattened piece of the
	 * mod's own text. An empty array means the mod looks healthy.
	 */
	public static function lines(folder:String):Array<String>
	{
		var out:Array<String> = [];
		var report:ModHealthReport = report(folder);
		if(report.severity == NO_PROBLEMS) return out;

		if(report.loadError != null)
			out.push('Last load error: ' + report.loadError.script + ' - ' + report.loadError.message);

		if(report.invalidPack != null)
			out.push('pack.json could not be used: ' + report.invalidPack);

		if(report.blocked.length > 0)
		{
			var first:BlockedScript = report.blocked[0];
			var where:String = first.language == 'runtime' ? ' inside ' : ' in ';
			var more:Int = report.blocked.length - 1;
			out.push('Blocked by the sandbox: ' + first.rules.join(', ') + where + first.script
				+ (more > 0 ? ' (+' + plural(more, 'more script') + ')' : ''));
		}

		if(report.missingAssets > 0)
		{
			var shown:Array<String> = report.missingList.slice(0, MAX_SHOWN_ASSETS);
			var rest:Int = report.missingAssets - shown.length;
			var list:String = shown.join(', ');
			if(rest > 0) list += (list.length > 0 ? ', ' : '') + '+' + rest + ' more';
			out.push(plural(report.missingAssets, 'missing asset') + (list.length > 0 ? ': ' + list : ''));
		}
		return out;
	}

	// -- Ownership and lifetime --------------------------------------------------

	/**
	 * The mod folder that owns a resolved asset path, or `null` when it is an
	 * engine asset or loose shared content under `mods/`.
	 *
	 * Any path with a `mods/` segment belongs to the folder right after it, the
	 * same rule `backend.MemoryLedger` uses to attribute RAM.
	 */
	public static function folderForPath(path:String):Null<String>
	{
		if(path == null || path.length == 0) return null;
		var parts:Array<String> = normalize(path).split('/');
		for(i in 0...parts.length)
		{
			if(parts[i] != 'mods') continue;
			if(i + 1 >= parts.length) return null;
			var folder:String = parts[i + 1];
			if(folder.length == 0 || folder.startsWith('.')) return null;
			return SHARED_FOLDERS.contains(folder.toLowerCase()) ? null : folder;
		}
		return null;
	}

	/**
	 * Drops everything recorded for one mod. Called when new files are installed
	 * into its folder (the `.zip` import flow): the old report described the mod
	 * that used to be there.
	 */
	public static function forget(folder:String):Void
	{
		if(folder == null) return;
		invalidPacks.remove(folder);
		loadErrors.remove(folder);
		blockedScripts.remove(folder);
		missingSeen.remove(folder);
		missingListed.remove(folder);
	}

	/**
	 * Drops everything recorded for folders that are no longer installed, keeping
	 * the reports of `folders` (the list the Mods menu was built from).
	 *
	 * Attribution is by folder name, so without this an uninstalled mod's failure
	 * would be shown for whatever is put in a folder with the same name later in
	 * the session.
	 *
	 * @param folders mod folders that are still installed
	 */
	public static function keepOnly(folders:Array<String>):Void
	{
		if(folders == null) return;
		var keep:Map<String, Bool> = [];
		for(folder in folders) keep.set(folder, true);

		for(folder in [for(key in invalidPacks.keys()) key]) if(!keep.exists(folder)) invalidPacks.remove(folder);
		for(folder in [for(key in loadErrors.keys()) key]) if(!keep.exists(folder)) loadErrors.remove(folder);
		for(folder in [for(key in blockedScripts.keys()) key]) if(!keep.exists(folder)) blockedScripts.remove(folder);
		for(folder in [for(key in missingSeen.keys()) key]) if(!keep.exists(folder)) missingSeen.remove(folder);
		for(folder in [for(key in missingListed.keys()) key]) if(!keep.exists(folder)) missingListed.remove(folder);
	}

	/** Drops every recorded problem, so a new session starts from a clean slate. */
	public static function clear():Void
	{
		invalidPacks = [];
		loadErrors = [];
		blockedScripts = [];
		missingSeen = [];
		missingListed = [];
	}

	// -- Helpers -----------------------------------------------------------------

	/** The part of `path` below `mods/<folder>/`, or the whole path when it is not under it. */
	static function withinFolder(folder:String, path:String):String
	{
		if(path == null) return '';
		var normalized:String = normalize(path);
		var marker:String = 'mods/' + folder + '/';
		var index:Int = normalized.lastIndexOf(marker);
		return index < 0 ? normalized : normalized.substr(index + marker.length);
	}

	static inline function normalize(path:String):String
		return path.split('\\').join('/');

	/** The rule id a runtime block message names, or `engine.blocked` when it names none. */
	static function runtimeRule(capability:String):String
	{
		var candidate:Null<String> = null;
		var token:StringBuf = new StringBuf();
		var index:Int = 0;
		while(index <= capability.length)
		{
			var code:Null<Int> = index < capability.length ? capability.charCodeAt(index) : null;
			if(code != null && isRuleCode(code))
			{
				token.add(capability.charAt(index));
			}
			else if(token.length > 0)
			{
				var word:String = token.toString();
				token = new StringBuf();
				if(isRuleId(word)) candidate = word;
			}
			index++;
		}
		return candidate != null ? candidate : 'engine.blocked';
	}

	inline static function isRuleCode(code:Int):Bool
		return (code >= 'a'.code && code <= 'z'.code) || (code >= '0'.code && code <= '9'.code)
			|| code == '.'.code || code == '-'.code;

	/** A rule id: lowercase words joined by single dots or hyphens, like every id in the scanner. */
	static function isRuleId(word:String):Bool
	{
		if(word == null || word.length < 3 || word.length > MAX_RULE) return false;
		if(word.indexOf('.') < 0 && word.indexOf('-') < 0) return false;
		return word.charAt(0) != '.' && word.charAt(0) != '-'
			&& word.charAt(word.length - 1) != '.' && word.charAt(word.length - 1) != '-';
	}

	/** A script path as the panel shows it: never empty. */
	static function scriptLabel(script:String):String
		return script == null || script.length == 0 ? '<inline script>' : script;

	/**
	 * Text written by a mod, flattened into one line of at most `max` characters so
	 * it cannot move the panel's own text or inject line breaks. Control characters
	 * become single spaces, leading/trailing space is dropped, and a longer input is
	 * cut with a trailing `...`.
	 */
	static function sanitize(text:String, max:Int):String
	{
		if(text == null || max < 4) return '';
		var out:StringBuf = new StringBuf();
		var written:Int = 0;
		var lastWasSpace:Bool = false;
		var index:Int = 0;
		while(index < text.length && written < max)
		{
			var code:Null<Int> = text.charCodeAt(index);
			index++;
			if(code == null) continue;
			if(code < 0x20 || code == 0x7F || code == ' '.code)
			{
				// Line breaks, tabs and runs of spaces all collapse into one space.
				if(lastWasSpace) continue;
				out.add(' ');
				lastWasSpace = true;
			}
			else
			{
				out.add(text.charAt(index - 1));
				lastWasSpace = false;
			}
			written++;
		}

		var result:String = out.toString().trim();
		if(index < text.length && result.length > 3) result = result.substr(0, max - 3) + '...';
		return result;
	}

	/** How many keys a map holds (Maps carry no `length`). */
	static function countKeys(map:Map<String, Dynamic>):Int
	{
		var total:Int = 0;
		for(key in map.keys()) total++;
		return total;
	}

	/** `1 missing asset`, `2 missing assets`: the nouns used here all take a plain `s`. */
	static function plural(count:Int, noun:String):String
		return (count == 1 ? '1 ' : count + ' ') + noun + (count == 1 ? '' : 's');

	static function isModFolder(folder:Null<String>):Bool
		return folder != null && folder.trim().length > 0 && folder.indexOf('\n') < 0 && folder.indexOf('\r') < 0;
}
