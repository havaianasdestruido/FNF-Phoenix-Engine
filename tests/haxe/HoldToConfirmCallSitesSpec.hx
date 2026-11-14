import sys.FileSystem;
import sys.io.File;

/**
 * Pins the *call sites* of `objects.HoldToConfirm`, not just its state machine.
 *
 * The "Exit to game" bug was not in `backend.HoldToConfirmLogic` - that module
 * was correct and its spec passed the whole time. Every guard was simply fed
 * `controls.ACCEPT`, and `backend.Controls` binds `ACCEPT` as `JUST_PRESSED`,
 * so the flag is true for exactly one frame. The state machine read that as
 * "pressed, then released on the next frame", so `MODE_HOLD` cancelled the
 * gesture immediately: the green bar drew for a single frame (which matches the
 * report exactly) and holding did nothing, forever.
 *
 * `Controls` already had `ACCEPT_P`, the same physical bind sampled as
 * `PRESSED`, and `StatsState` was the only guard using it. This spec walks the
 * guarded call sites and fails if a guard's `held` callback reads a
 * just-pressed flag again.
 *
 * Only the constructor arguments are scanned: `controls.ACCEPT` is correct
 * everywhere else (menus act on the press itself), so flagging those would be
 * noise.
 *
 * Run with: bash tests/haxe/run-hold-to-confirm.sh
 */
class HoldToConfirmCallSitesSpec
{
	/**
	 * Files that construct a `HoldToConfirm` with a keyboard/gamepad `held`
	 * callback. Extend this list when a new guarded action is added - a guard
	 * that reads a just-pressed flag silently never fires.
	 */
	static final GUARDED_SITES:Array<String> = [
		'source/states/substates/PauseSubState.hx',
		'source/states/substates/ResetScoreSubState.hx',
		'source/states/substates/GameplayChangersSubstate.hx',
		'source/states/StatsState.hx',
		'source/options/BaseOptionsMenu.hx',
		'source/objects/Prompt.hx',
	];

	/** `.ACCEPT` / `.RESET` but not `.ACCEPT_P` / `.RESET_P`. */
	static final JUST_PRESSED_FLAG:EReg = ~/\.(ACCEPT|RESET)(?![A-Za-z0-9_])/g;

	static var failures:Int = 0;

	static function check(ok:Bool, label:String):Void
	{
		if (ok) return;
		failures++;
		Sys.println('FAILED: $label');
	}

	public static function main():Void
	{
		for (path in GUARDED_SITES)
		{
			if (!FileSystem.exists(path))
			{
				Sys.println('SKIP: $path (spec copied out of the repo)');
				continue;
			}
			scan(path, File.getContent(path));
		}

		if (failures > 0) throw '$failures hold-to-confirm call-site check(s) failed';
		Sys.println('HoldToConfirmCallSitesSpec passed');
	}

	/**
	 * Collects each `new HoldToConfirm(...)` call by balancing parentheses, then
	 * checks the arguments for flags that cannot describe a hold.
	 */
	static function scan(path:String, source:String):Void
	{
		final marker:String = 'new HoldToConfirm(';
		var found:Int = 0;
		var from:Int = 0;

		while (true)
		{
			var start:Int = source.indexOf(marker, from);
			if (start == -1) break;
			found++;
			from = start + marker.length;

			var depth:Int = 0;
			var i:Int = start + marker.length - 1; // the '(' of the call
			var end:Int = -1;
			while (i < source.length)
			{
				var c:String = source.charAt(i);
				if (c == '(') depth++;
				else if (c == ')')
				{
					depth--;
					if (depth == 0)
					{
						end = i + 1;
						break;
					}
				}
				i++;
			}
			if (end == -1) continue;

			final call:String = source.substring(start, end);
			checkGuardArguments(path, source, start, call);
		}

		check(found > 0, '$path no longer constructs a HoldToConfirm');
	}

	static function checkGuardArguments(path:String, source:String, offset:Int, call:String):Void
	{
		// Strip line comments first: a guard may explain *why* it avoids the
		// just-pressed flag, and that explanation names it.
		if (!JUST_PRESSED_FLAG.match(stripLineComments(call))) return;

		final line:Int = lineAt(source, offset);
		check(false,
			'$path:$line passes a JUST_PRESSED-only flag to a HoldToConfirm; '
			+ 'use ACCEPT_P / RESET_P so the hold stays true across frames -> '
			+ oneLine(call));
	}

	/** Drops `// ...` tails so explanatory comments cannot trip the scan. */
	static function stripLineComments(text:String):String
	{
		final out:Array<String> = [];
		for (line in text.split('\n'))
		{
			final at:Int = line.indexOf('//');
			out.push(at == -1 ? line : line.substring(0, at));
		}
		return out.join('\n');
	}

	/** 1-based line number of a character offset. */
	static function lineAt(source:String, offset:Int):Int
	{
		var line:Int = 1;
		var i:Int = 0;
		while (i < offset && i < source.length)
		{
			if (source.charAt(i) == '\n') line++;
			i++;
		}
		return line;
	}

	/** Collapses a multi-line call into one readable line for the failure text. */
	static function oneLine(call:String):String
	{
		var out:String = call.split('\n').join(' ');
		while (out.indexOf('  ') != -1) out = out.split('  ').join(' ');
		return StringTools.trim(out);
	}
}
