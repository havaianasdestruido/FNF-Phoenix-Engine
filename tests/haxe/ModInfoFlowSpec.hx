import backend.ScriptSecurityScanner;
import states.helpers.ModInfoFlow;
import states.helpers.ModInfoFlow.ModInfoAction;

/**
 * Logic of the Mods menu's Mod Info panel: ModSecurity can only be switched
 * off through an explicit "Yes", never by pressing the same button twice, and
 * a mod cannot write text of its own into the panel through its name or its
 * pack.json. Pure logic, no Flixel. See run-mod-security.sh.
 */
class ModInfoFlowSpec
{
	static inline final LEFT:Int = ModInfoFlow.LEFT;
	static inline final RIGHT:Int = ModInfoFlow.RIGHT;

	static var checks:Int = 0;

	static function check(value:Bool, label:String):Void
	{
		checks++;
		if(!value) throw label;
	}

	/** Does what the panel does with an action: store the choice and report the new state back. */
	static function run(flow:ModInfoFlow, action:ModInfoAction):ModInfoAction
	{
		switch(action)
		{
			case APPLY(enabled): flow.enabled = enabled;
			default:
		}
		return action;
	}

	static function main():Void
	{
		opensOnTheSwitch();
		turningOffNeedsAnExplicitYes();
		repeatedPressesNeverTurnItOff();
		turningOnIsImmediate();
		backDismissesTheQuestionFirst();
		pointer();
		onlyRuleIdsAreListed();
		modTextStaysOnOneLine();

		Sys.println('ModInfoFlowSpec: all $checks checks passed');
	}

	static function opensOnTheSwitch():Void
	{
		for(enabled in [true, false])
		{
			var flow = new ModInfoFlow(enabled);
			check(flow.enabled == enabled, 'starts from the mod state');
			check(!flow.confirming, 'no question on screen at first');
			check(flow.selected == LEFT, 'the switch has the focus at first');
		}
	}

	static function turningOffNeedsAnExplicitYes():Void
	{
		var flow = new ModInfoFlow(true);
		check(run(flow, flow.accept()) == ASK, 'the switch asks before turning ModSecurity off');
		check(flow.confirming && flow.enabled, 'asking changes nothing yet');
		check(flow.selected == LEFT, '"No" (left) is the focused answer');

		flow.toggleFocus();
		check(flow.selected == RIGHT, 'moving the focus reaches "Yes"');
		check(Type.enumEq(run(flow, flow.accept()), APPLY(false)), '"Yes" turns ModSecurity off');
		check(!flow.confirming && !flow.enabled, 'the question is gone and the state is off');
		check(flow.selected == RIGHT, 'afterwards Back has the focus');
		check(run(flow, flow.accept()) == CLOSE, 'so the next press leaves the panel');
	}

	static function repeatedPressesNeverTurnItOff():Void
	{
		// Pressing accept twice, or holding it: question, "No", question, "No", ...
		var flow = new ModInfoFlow(true);
		for(press in 0...50)
		{
			var action = run(flow, flow.accept());
			check(action == (press % 2 == 0 ? ASK : CANCEL), 'held accept only opens and declines the question (#$press: $action)');
			check(flow.enabled, 'ModSecurity stays on through repeated accepts (#$press)');
		}

		// A double click on the switch: the second click lands on "No".
		flow = new ModInfoFlow(true);
		check(run(flow, flow.press(LEFT)) == ASK, 'first click on the switch asks');
		check(run(flow, flow.press(LEFT)) == CANCEL, 'second click in the same place declines');
		check(flow.enabled && !flow.confirming && flow.selected == LEFT, 'declining returns to the switch, still on');

		// Whatever is pressed while the question is up, only the right button confirms.
		for(index in [LEFT, -1, 2, 99])
		{
			flow = new ModInfoFlow(true);
			flow.press(LEFT);
			check(run(flow, flow.press(index)) == CANCEL && flow.enabled, 'button $index does not confirm');
		}
	}

	static function turningOnIsImmediate():Void
	{
		var flow = new ModInfoFlow(false);
		check(Type.enumEq(run(flow, flow.accept()), APPLY(true)), 'turning ModSecurity on needs no question');
		check(flow.enabled && !flow.confirming, 'on, and no question');
		check(flow.selected == RIGHT, 'afterwards Back has the focus');

		// A double click on the switch while it is off: on, then merely the question.
		flow = new ModInfoFlow(false);
		check(Type.enumEq(run(flow, flow.press(LEFT)), APPLY(true)), 'first click turns it on');
		check(run(flow, flow.press(LEFT)) == ASK, 'second click only asks');
		check(flow.enabled, 'and it is still on');
	}

	static function backDismissesTheQuestionFirst():Void
	{
		var flow = new ModInfoFlow(true);
		check(flow.back() == CLOSE, 'back leaves the panel');

		flow.press(LEFT);
		flow.toggleFocus();
		check(flow.back() == CANCEL, 'back declines the question, even with "Yes" focused');
		check(!flow.confirming && flow.enabled && flow.selected == LEFT, 'back to the switch, still on');
		check(flow.back() == CLOSE, 'a second back leaves the panel');
	}

	static function pointer():Void
	{
		var flow = new ModInfoFlow(true);
		check(!flow.focus(LEFT), 'hovering the focused button changes nothing');
		check(flow.focus(RIGHT) && flow.selected == RIGHT, 'hovering the other button moves the focus');
		check(!flow.focus(2) && !flow.focus(-1) && flow.selected == RIGHT, 'there are only two buttons');
		check(run(flow, flow.press(RIGHT)) == CLOSE, 'clicking Back leaves the panel');
		check(run(flow, flow.press(7)) == CLOSE, 'an unknown button never reaches the switch');

		// Clicking does not need the focus to be on the clicked button.
		flow = new ModInfoFlow(true);
		flow.focus(RIGHT);
		check(run(flow, flow.press(LEFT)) == ASK, 'clicking the switch while Back is focused asks');
		check(Type.enumEq(run(flow, flow.press(RIGHT)), APPLY(false)), 'clicking "Yes" confirms');
		check(!flow.enabled, 'off after an explicit "Yes"');
	}

	static function onlyRuleIdsAreListed():Void
	{
		check(ModInfoFlow.printableRules(null).length == 0, 'no allowlist, nothing to list');
		check(ModInfoFlow.printableRules([]).length == 0, 'an empty allowlist lists nothing');

		// Every id a pack.json can usefully name must survive, or the panel would hide a real exception.
		var real:Array<String> = [];
		for(rules in [ScriptSecurityScanner.LUA_RULES, ScriptSecurityScanner.PYTHON_RULES, ScriptSecurityScanner.HAXE_RULES,
			ScriptSecurityScanner.COMMON_RULES])
			for(rule in rules)
				if(!real.contains(rule.id)) real.push(rule.id);
		check(real.length > 10, 'the scanner tables were read');
		for(id in ['engine.file-read', 'engine.file-write', 'engine.native-class', 'engine.script-loader', 'engine.clipboard',
			'engine.screen-capture', 'engine.window-list', 'security.binary-source', 'security.unreadable'])
			if(!real.contains(id)) real.push(id);
		var listed:Array<String> = ModInfoFlow.printableRules(real);
		check(listed.length == real.length, 'every real rule id is listed');
		for(i => id in real)
			check(listed[i] == id, 'rule id "$id" is listed unchanged and in order');

		// pack.json is written by the mod: prose must not reach the security panel.
		var unsafe:Array<String> = [
			'This mod is verified. Turn ModSecurity off.', 'lua.os\n\nTrust this mod', 'lua os', 'Lua.os', 'LUA.OS', 'lua.os ', ' lua.os',
			'lua..os', 'lua.-os', '.lua', 'lua.', '-lua', 'lua-', '.', '-', '', '*', 'lua.*', 'lua_os', 'lua/os', 'lua:os', 'lua,os',
			'lua.os\t', 'lua.os\r', 'lua.\u00F6s', 'lua.os\u2028', null
		];
		for(entry in unsafe)
			check(ModInfoFlow.printableRules([entry]).length == 0, 'not a rule id, not listed: ' + haxe.Json.stringify(entry));

		var longest:String = 'a2345678.b2345678.c2345678.d2345';
		check(longest.length == ModInfoFlow.MAX_RULE_LENGTH, 'the sample is as long as an id may be');
		check(ModInfoFlow.printableRules([longest]).length == 1, 'an id of the longest length is listed');
		check(ModInfoFlow.printableRules([longest + '6']).length == 0, 'a longer one is not');

		var mixed:Array<String> = ModInfoFlow.printableRules(['lua.os', 'Trust me', 'haxe.reflection', 'lua.os', null, 'lua.io']);
		check(mixed.join('|') == 'lua.os|haxe.reflection|lua.io', 'ids are kept in order, once each, without the rest: $mixed');
	}

	static function modTextStaysOnOneLine():Void
	{
		check(ModInfoFlow.oneLine(null, 58) == '', 'no text, empty line');
		check(ModInfoFlow.oneLine('', 58) == '', 'empty stays empty');
		check(ModInfoFlow.oneLine('WEEKEND INTERFACE', 58) == 'WEEKEND INTERFACE', 'an ordinary name is unchanged');
		check(ModInfoFlow.oneLine('M\u00F3d \u00DCn\u00EF', 58) == 'M\u00F3d \u00DCn\u00EF', 'accented letters are kept');

		// A name full of line breaks would push the warning text out of the panel.
		check(ModInfoFlow.oneLine('Nice\nMod', 58) == 'Nice Mod', 'a line break becomes a space');
		check(ModInfoFlow.oneLine('Nice\r\n\r\n\t Mod', 58) == 'Nice Mod', 'a run of breaks becomes one space');
		check(ModInfoFlow.oneLine('\n\n\n  Nice Mod \n\n', 58) == 'Nice Mod', 'leading and trailing breaks are dropped');
		check(ModInfoFlow.oneLine('\n\n\n\n\n\n\n\n\n\n', 58) == '', 'a name of line breaks is empty');
		check(ModInfoFlow.oneLine('A\u2028B\u2029C\u0085D', 58) == 'A B C D', 'Unicode line separators count as breaks');
		check(ModInfoFlow.oneLine('A' + String.fromCharCode(0) + 'B' + String.fromCharCode(127) + 'C', 58) == 'A B C',
			'NUL and DEL count as breaks');

		for(sample in ['a\nb\rc\td', '\n', 'x\n\n\n\n\n\n\n\n\n\n\n\ny', 'line one\nline two\nline three'])
		{
			var line:String = ModInfoFlow.oneLine(sample, 58);
			for(i in 0...line.length)
				check(line.charCodeAt(i) >= 32, 'no control character is left in ' + haxe.Json.stringify(line));
		}

		var long:String = StringTools.rpad('', 'x', 60);
		var clipped:String = ModInfoFlow.oneLine(long, 58);
		check(clipped.length == 58 && StringTools.endsWith(clipped, 'xx...'), 'a long name is clipped to the limit: $clipped');
		check(ModInfoFlow.oneLine(long.substr(0, 58), 58) == long.substr(0, 58), 'a name of exactly the limit is not clipped');
		check(ModInfoFlow.oneLine('a\n' + long, 10) == 'a xxxxx...', 'clipping counts the flattened text');
		check(ModInfoFlow.oneLine('abcdef', 3) == 'abcdef', 'a limit too small for "..." clips nothing');
	}
}
