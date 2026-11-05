package backend;

import openfl.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Runtime, user-editable engine configuration loaded from `flags.ini` in the
 * working directory. The bundled copy is only a source of defaults; the
 * working-directory file always wins. Runtime flags intentionally control
 * behavior only and cannot enable code omitted by compile-time feature flags.
 */
class RuntimeFlags
{
	public static inline var FILE_NAME:String = "flags.ini";
	static var values:Map<String, String> = new Map();
	static var loaded:Bool = false;

	/** Read once during bootstrap. Safe to call repeatedly. */
	public static function load(?force:Bool = false):Void
	{
		if (loaded && !force) return;
		loaded = true;
		values = new Map();

		var text:Null<String> = null;
		#if sys
		for (path in [FILE_NAME, "assets/" + FILE_NAME])
		{
			try
			{
				if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
				{
					text = File.getContent(path);
					break;
				}
			}
			catch (error:Dynamic)
				trace('Could not read runtime flags from $path: $error');
		}
		#end

		if (text == null)
		{
			try
			{
				if (Assets.exists("flags.ini")) text = Assets.getText("flags.ini");
				else if (Assets.exists("assets/flags.ini")) text = Assets.getText("assets/flags.ini");
			}
			catch (error:Dynamic)
				trace('Could not read bundled runtime flags: $error');
		}
		if (text != null) parse(text);
	}

	/** Parse INI sections and key/value pairs; comments and unknown keys are ignored. */
	public static function parse(text:String):Void
	{
		loaded = true;
		values = new Map();
		if (text == null) return;
		var section:String = "";
		for (rawLine in text.split("\n"))
		{
			var line:String = StringTools.trim(rawLine);
			if (line.length == 0 || StringTools.startsWith(line, ";") || StringTools.startsWith(line, "#")) continue;
			if (StringTools.startsWith(line, "[") && StringTools.endsWith(line, "]"))
			{
				section = StringTools.trim(line.substring(1, line.length - 1)).toLowerCase();
				continue;
			}

			var equals:Int = line.indexOf("=");
			if (equals <= 0) continue;
			var key:String = StringTools.trim(line.substring(0, equals)).toLowerCase();
			var value:String = StringTools.trim(line.substring(equals + 1));
			// Inline comments are recognized only when separated by whitespace,
			// so URLs and values containing # remain intact.
			var comment:Int = inlineCommentIndex(value);
			if (comment >= 0) value = StringTools.trim(value.substring(0, comment));
			if (key.length == 0) continue;
			values.set(section.length == 0 ? key : section + "." + key, unquote(value));
		}
	}

	static function inlineCommentIndex(value:String):Int
	{
		for (i in 1...value.length)
		{
			var previous:Int = value.charCodeAt(i - 1);
			if ((value.charAt(i) == ";" || value.charAt(i) == "#") && (previous == 32 || previous == 9 || previous == 13)) return i;
		}
		return -1;
	}

	static function unquote(value:String):String
	{
		if (value.length >= 2)
		{
			var first:String = value.charAt(0);
			var last:String = value.charAt(value.length - 1);
			if ((first == "\"" && last == "\"") || (first == "'" && last == "'"))
				return value.substring(1, value.length - 1);
		}
		return value;
	}

	public static function has(key:String):Bool
	{
		load();
		return values.exists(normalizeKey(key));
	}

	public static function getString(key:String, ?fallback:String = ""):String
	{
		load();
		var value:Null<String> = values.get(normalizeKey(key));
		return value == null ? fallback : value;
	}

	public static function getBool(key:String, ?fallback:Bool = false):Bool
	{
		var value:String = getString(key, null);
		if (value == null) return fallback;
		switch (value.toLowerCase())
		{
			case "true", "yes", "on", "1": return true;
			case "false", "no", "off", "0": return false;
			default: return fallback;
		}
	}

	public static function getInt(key:String, ?fallback:Int = 0):Int
	{
		var value:String = getString(key, null);
		if (value == null) return fallback;
		var parsed:Null<Int> = Std.parseInt(value);
		return parsed == null ? fallback : parsed;
	}

	/** Stable app keys are section-qualified, e.g. `window.title`. */
	static function normalizeKey(key:String):String
		return key == null ? "" : StringTools.trim(key).toLowerCase();

	/** Resolve the configurable title, leaving an asset-provided default intact. */
	public static function windowTitle(assetDefault:String):String
	{
		var configured:String = StringTools.trim(getString("window.title", ""));
		return configured.length > 0 ? configured : assetDefault;
	}

	/** Configured URLs must be absolute HTTP(S) links before being opened. */
	public static function url(key:String, fallback:String):String
	{
		var value:String = StringTools.trim(getString(key, fallback));
		return StringTools.startsWith(value, "https://") || StringTools.startsWith(value, "http://") ? value : fallback;
	}

	/** True when the running engine reports an alpha/beta/pre/rc version. */
	public static function isPrerelease():Bool
		return PhoenixVersion.normalize(PhoenixVersion.current) != null && PhoenixVersion.current.indexOf("-") >= 0;
}
