package backend.deeplink;

/**
 * Phoenix URI routing — platform-independent deep-link contract.
 *
 * v1 (menu-only) was `phoenix://main|mods|options|misc|story|freeplay|credits`
 *                (+ `phoenix://menu/<name>` alias).
 * v2 extends it without breaking v1:
 *   - phoenix://song/<song>?difficulty=<diff>
 *   - phoenix://mod/<modId>/song/<song>
 *   - phoenix://screen/<freeplay|mods|options|...>
 *   - phoenix://diagnostics
 *   - phoenix://replay/<id>
 *
 * All inputs are bounded (256 chars), validated against an allowlist, and
 * never touch the filesystem directly — the router resolves them to in-game
 * navigation after verification. Unknown hosts/paths return null.
 */
class PhoenixURI
{
	public static inline var MAX_LEN:Int = 256;

	/** Version 1 compatibility: returns the menu route string or null. */
	public static function parse(uri:String):Null<String>
	{
		if (uri == null || uri.length > MAX_LEN) return null;
		// Restrict the whole input, rather than accepting a valid prefix.
		var syntax = ~/^phoenix:\/\/([a-z]+)(\/([a-z]+))?\/?$/i;
		if (!syntax.match(uri) || syntax.matched(0) != uri) return null;
		var host = syntax.matched(1).toLowerCase();
		var path = syntax.matched(3);
		if (host == "menu")
			host = path == null ? "main" : path.toLowerCase();
		else if (path != null)
			return null;
		return switch (host)
		{
			case "main", "mods", "options", "misc", "story", "freeplay", "credits": host;
			default: null;
		};
	}

	/** Full v2 parser: returns structured route or null on invalid URI. */
	public static function parseEx(uri:String):Null<ParsedURI>
	{
		if (uri == null || uri.length == 0 || uri.length > MAX_LEN) return null;
		// Must match the entire input, not just a prefix.
		var syntax = ~/^phoenix:\/\/([a-z0-9_-]+)(\/[^?#]*)?(\?([^#]*))?$/i;
		if (!syntax.match(uri) || syntax.matched(0) != uri) return null;

		var host = syntax.matched(1).toLowerCase();
		var rawPath = syntax.matched(2);
		var rawQuery = syntax.matched(4);

		var query = parseQuery(rawQuery);
		var pathParts:Array<String> = [];
		if (rawPath != null && rawPath.length > 0)
		{
			// Strip leading slash, split, lower-case hosts/keys but preserve mod/song ids case-insensitively.
			var cleaned = rawPath;
			if (cleaned.charAt(0) == "/") cleaned = cleaned.substr(1);
			if (cleaned.length > 0 && cleaned.charAt(cleaned.length - 1) == "/") cleaned = cleaned.substr(0, cleaned.length - 1);
			if (cleaned.length > 0)
			{
				for (part in cleaned.split("/"))
				{
					if (part.length == 0) return null;
					// Allow alphanumeric, dash, underscore only
					if (!~/^[a-z0-9_-]+$/i.match(part)) return null;
					pathParts.push(part.toLowerCase());
				}
			}
		}

		// Route by host
		return switch (host)
		{
			case "menu":
				// menu/<name> alias for v1
				if (pathParts.length == 0) mk(Menu("main"), query);
				else if (pathParts.length == 1) mk(Menu(pathParts[0]), query);
				else null;
			case "main", "mods", "options", "misc", "story", "freeplay", "credits":
				if (pathParts.length != 0) return null;
				mk(Menu(host), query);
			case "screen":
				if (pathParts.length != 1) return null;
				mk(Screen(pathParts[0]), query);
			case "song":
				if (pathParts.length != 1) return null;
				mk(Song(pathParts[0], query.get("difficulty")), query);
			case "mod":
				// mod/<modId>/song/<song> or mod/<modId>
				if (pathParts.length == 1) mk(Mod(pathParts[0], null), query);
				else if (pathParts.length == 3 && pathParts[1] == "song") mk(Mod(pathParts[0], pathParts[2]), query);
				else null;
			case "diagnostics":
				if (pathParts.length != 0) return null;
				mk(Diagnostics, query);
			case "replay":
				if (pathParts.length != 1) return null;
				mk(Replay(pathParts[0]), query);
			default: null;
		};
	}

	static function mk(kind:URIKind, query:Map<String, String>):ParsedURI
	{
		// Validate kind-specific allowlists
		switch (kind)
		{
			case Menu(route), Screen(route):
				if (["main", "mods", "options", "misc", "story", "freeplay", "credits"].indexOf(route) == -1)
					return null;
			case Song(_, diff):
				if (diff != null && diff.length > 0 && !~/^[a-z0-9_-]+$/i.match(diff))
					return null;
			default:
		}
		return {kind: kind, query: query};
	}

	static function parseQuery(raw:Null<String>):Map<String, String>
	{
		var map:Map<String, String> = [];
		if (raw == null || raw.length == 0) return map;
		for (pair in raw.split("&"))
		{
			if (pair.length == 0) continue;
			var kv = pair.split("=");
			var k = kv[0].toLowerCase();
			var v = kv.length > 1 ? kv[1] : "";
			// Decode + as space, %XX, and allowlist
			try
			{
				v = StringTools.urlDecode(v);
			}
			catch (e:Dynamic) {}
			if (k.length > 0 && k.length < 32 && v.length < 64)
				map.set(k, v);
		}
		return map;
	}
}


