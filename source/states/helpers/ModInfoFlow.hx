package states.helpers;

using StringTools;

/** What a press in Mod Info asks the panel to do. */
enum ModInfoAction
{
	/** Leave the panel. */
	CLOSE;

	/** Put the "turn ModSecurity off?" question on screen. */
	ASK;

	/** The question was answered "No": back to the switch, nothing changed. */
	CANCEL;

	/** Store the player's choice: ModSecurity on (`true`) or off (`false`). */
	APPLY(enabled:Bool);
}

/**
 * Logic of Mod Info (`states.substates.ModInfoSubState`), kept free of Flixel
 * so its rules run in tests without a renderer: what the two buttons do, and
 * which text written by the mod the panel may print.
 *
 * The panel always shows two buttons: normally the ModSecurity switch (left)
 * and Back (right). Switching ModSecurity off is the risky direction, so it
 * first swaps them for a question whose "No" is on the left, where the switch
 * was, and holds the focus. Pressing twice, a double click or a held key can
 * therefore never confirm it. Switching it back on needs no question.
 *
 * The panel is where the player decides whether to trust a mod, so the mod
 * must not be able to write into it: its name is flattened to one line
 * (`oneLine`) and only rule ids are listed from its `pack.json` (`printableRules`).
 */
class ModInfoFlow
{
	public static inline final LEFT:Int = 0;
	public static inline final RIGHT:Int = 1;

	/** Longest rule id the panel prints. Real ids are shorter (`python.dangerous-import`). */
	public static inline final MAX_RULE_LENGTH:Int = 32;

	/**
	 * The `scriptSandboxAllowlist` entries the panel may print. Only entries
	 * shaped like a rule id (`lua.os`, `engine.file-write`) are kept: anything
	 * else matches no rule, so it changes nothing about the sandbox, and it
	 * would put the mod's own words inside the security panel.
	 */
	public static function printableRules(allowlist:Array<String>):Array<String>
	{
		var rules:Array<String> = [];
		if(allowlist == null) return rules;
		for(entry in allowlist)
			if(isRuleId(entry) && !rules.contains(entry)) rules.push(entry);
		return rules;
	}

	/** Lowercase words of letters and digits joined by single dots or hyphens, like every rule id. */
	static function isRuleId(entry:String):Bool
	{
		if(entry == null || entry.length == 0 || entry.length > MAX_RULE_LENGTH) return false;
		var afterSeparator:Bool = true; // an id starts and ends with a letter or digit
		for(i in 0...entry.length)
		{
			var code:Null<Int> = entry.charCodeAt(i);
			if(code == null) return false;
			if((code >= 'a'.code && code <= 'z'.code) || (code >= '0'.code && code <= '9'.code)) afterSeparator = false;
			else if((code == '.'.code || code == '-'.code) && !afterSeparator) afterSeparator = true;
			else return false;
		}
		return !afterSeparator;
	}

	/**
	 * The body of the Mod Info panel's "problems" block: what went wrong with the
	 * selected mod (`backend.ModHealth`), wrapped to `maxChars` per line so it fits
	 * the panel's width without a horizontal scroll.
	 *
	 * The block never repeats raw mod text: each entry comes from `ModHealth.lines()`
	 * already flattened to one bounded line, so a broken script cannot use its own
	 * error message to draw outside the panel.
	 *
	 * @param lines lines of the report, as `backend.ModHealth.lines()` returns them
	 * @param maxChars characters per wrapped line (a word longer than this is cut)
	 * @param maxLines lines shown before the rest is summarised
	 * @return the wrapped text, or `''` when there is nothing to report
	 */
	public static function problemsBlock(lines:Array<String>, maxChars:Int, maxLines:Int = 6):String
	{
		if(lines == null || lines.length == 0 || maxChars < 8 || maxLines < 1) return '';

		var wrapped:Array<String> = [];
		for(line in lines)
			for(part in wrap(line, maxChars)) wrapped.push(part);
		if(wrapped.length > maxLines)
		{
			var hidden:Int = wrapped.length - (maxLines - 1);
			wrapped = wrapped.slice(0, maxLines - 1);
			wrapped.push('...and ' + hidden + ' more line' + (hidden == 1 ? '' : 's') + '.');
		}
		return wrapped.join('\n');
	}

	/** Breaks one line into chunks of at most `maxChars`, preferring spaces. */
	public static function wrap(line:String, maxChars:Int):Array<String>
	{
		var out:Array<String> = [];
		if(line == null || maxChars < 8) return out;
		var rest:String = line;
		while(rest.length > maxChars)
		{
			var cut:Int = rest.lastIndexOf(' ', maxChars);
			if(cut < maxChars / 2) cut = maxChars;
			out.push(rest.substr(0, cut).trim());
			rest = rest.substr(cut).trim();
		}
		if(rest.length > 0) out.push(rest);
		return out;
	}

	/**
	 * Text written by a mod (its name, its folder) as one line of at most `max`
	 * characters. Line breaks, tabs and other control characters become single
	 * spaces, so a name cannot push the panel's own text out of view.
	 */
	public static function oneLine(text:String, max:Int):String
	{
		if(text == null) return '';
		var words:Array<String> = [];
		var wordStart:Int = -1;
		for(i in 0...text.length + 1)
		{
			var code:Null<Int> = i < text.length ? text.charCodeAt(i) : 32;
			// ASCII controls and space, DEL, NEL and the Unicode line/paragraph separators.
			if(code == null || code <= 32 || code == 127 || code == 0x85 || code == 0x2028 || code == 0x2029)
			{
				if(wordStart >= 0) words.push(text.substring(wordStart, i));
				wordStart = -1;
			}
			else if(wordStart < 0) wordStart = i;
		}
		var line:String = words.join(' ');
		return (max > 3 && line.length > max) ? line.substr(0, max - 3) + '...' : line;
	}

	/** Whether ModSecurity is on for the mod. The panel keeps this current after an `APPLY`. */
	public var enabled:Bool;

	/** `true` while the "turn it off?" question is on screen. */
	public var confirming(default, null):Bool = false;

	/** Focused button, `LEFT` or `RIGHT`. */
	public var selected(default, null):Int = LEFT;

	public function new(enabled:Bool)
	{
		this.enabled = enabled;
	}

	/** Moves the focus to the other button (left/right input). */
	public function toggleFocus():Void
	{
		selected = (selected == LEFT) ? RIGHT : LEFT;
	}

	/**
	 * Moves the focus to a button (pointer hover).
	 * @return whether the focus changed
	 */
	public function focus(index:Int):Bool
	{
		if((index != LEFT && index != RIGHT) || index == selected) return false;
		selected = index;
		return true;
	}

	/** Accept on the focused button. */
	public inline function accept():ModInfoAction
		return press(selected);

	/** A press on one of the two buttons: a click or tap, or accept on the focused one. */
	public function press(index:Int):ModInfoAction
	{
		if(confirming)
		{
			confirming = false;
			// Only the right button says "Yes"; anything else leaves ModSecurity on.
			if(index != RIGHT)
			{
				selected = LEFT;
				return CANCEL;
			}
			return apply(false);
		}

		if(index != LEFT) return CLOSE;
		if(!enabled) return apply(true);

		confirming = true;
		selected = LEFT; // "No"
		return ASK;
	}

	/** Back input: dismisses the question first, then the panel. */
	public function back():ModInfoAction
	{
		if(!confirming) return CLOSE;
		confirming = false;
		selected = LEFT;
		return CANCEL;
	}

	function apply(value:Bool):ModInfoAction
	{
		selected = RIGHT; // done: the next press leaves instead of switching back
		return APPLY(value);
	}
}
