package backend;

// an fully working crash handler on ALL platforms
import states.MainMenuState;
import flixel.FlxState;
import haxe.CallStack;
import haxe.io.Path;
import openfl.Lib;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;
#if android
import android.platform.AndroidNotification;
#end

import objects.Note;

/**
 * Crash Handler.
 * @author YoshiCrafter29 and MAJigsaw77
 */
class CrashHandler
{
	public static var errorMessage:String = "";

	public static final __superCoolErrorMessagesArray:Array<String> = [
		"A fatal error has occ- wait what?",
		"missigno.",
		"oopsie daisies!! you made a silly mistake!!",
		"i think you fogot a semicolon",
		"null reference",
		"get friday night funkd'",
		"engine skipped a heartbeat",
		"Impossible...",
		"Patience is key for success... Don't give up.",
		"It's no longer in its early stages... is it?",
		"It took me half a day to code that in",
		"You should make an issue... NOW!!",
		"> Crash Handler written by: yoshicrafter29",
		"broken ch-... wait what are we talking about",
		"could not access variable you.dad",
		"What have you done...",
		"THERE ARENT COUGARS IN SCRIPTING!!! I HEARD IT!!",
		"no, thats not from system.windows.forms",
		"you better link a screenshot if you make an issue, or at least the crash.txt",
		"stack trace more like dunno i dont have any jokes",
		"oh the misery. everybody wants to be my enemy",
		"have you heard of soulles dx",
		"i thought it was invincible",
		"did you deleted coconut.png",
		"have you heard of missing json's cousin null function reference",
		"sad that linux users wont see this banger of a crash handler",
		"woopsie",
		"oopsie",
		"woops",
		"silly me",
		"my bad",
		"first time, huh?",
		"did somebody say yoga",
		"we forget a thousand things everyday... make sure this is one of them.",
		"SAY GOODBYE TO YOUR KNEECAPS, CHUCKLEHEAD",
		"ordinal 344 (TaskDialog) forcing me to create an even fancier window",
		"Died due to missing a sawblade. (Press Space to dodge!)",
		"yes rico, kaboom.",
		"hey, while in freeplay, press shift while pressing space",
		"goofy ahh engine",
		"pssst, try typing debug7 in the options menu",
		"this crash handler is sponsored by rai-",
		"",
		"did you know a jiffy is an actual measurement of time",
		"how many hurt notes did you put",
		"FPS: 0",
		"\r\ni am a secret message",
		"this is garnet",
		"Error: Sorry i already have a girlfriend",
		"did you know theres a total of 51 silly messages",
		"whoopsies looks like i forgot to fix this",
		"Game used Crash. It's super effective!",
		"What in the world happened?!",
		"The engine got constipated. Sad.",
		"Something went wrong.",
		"NULL",
		"Five big booms. BOOM, BOOM, BOOM, BOOM, BOOM!!!!!!!!!!",
		"uhhhhhhhhhhhhhhhh... i dont think this is normal...",
		"lobotomy moment",
		"ARK: Survival Evolved",
		"my names JS Engine, and I'm an crashaholic",
		"JS, more like buggy engine lol"
	];

	// this is a map containing common crash sources mapped to a summarized reason, use to add an extra line on the crash screen.
	static final commonCrashers:Map<String, String> = [
		'SuperSecretDebugMenu.crashDaEngine()' => 'You intentionally caused this.',
		'Paths.addAnimAndCheck()' => "You're missing a config file for your note splash skin.",
		'JsonParser.invalidChar()' => "Your json is either formatted incorrectly or corrupted."
	];

	public static var extraLines:Array<String> = ['\n\n'];

	public static function init():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onError);
		#end
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		RecoveryBoot.markCrash();
		try
		{
			e.preventDefault();
			e.stopPropagation();
			e.stopImmediatePropagation();

			errorMessage = "";

			var m:String = e.error;
			if (Std.isOfType(e.error, Error))
			{
				var err = cast(e.error, Error);
				m = '${err.message}';
			}
			else if (Std.isOfType(e.error, ErrorEvent))
			{
				var err = cast(e.error, ErrorEvent);
				m = '${err.text}';
			}
			final stack = CallStack.exceptionStack();
			final stackLabelArr:Array<String> = [];
			var stackLabel:String = "";
			// legacy code below for the messages
			#if sys
			var path:String;
			var dateNow:String = Date.now().toString();
			dateNow = dateNow.replace(" ", "_");
			dateNow = dateNow.replace(":", "'");

			path = "crash/FNF-Phoenix-Engine_" + dateNow + ".log";
			#end

			for (stackItem in stack)
			{
				switch (stackItem)
				{
					case CFunction:
						stackLabelArr.push("Non-Haxe (C) Function");
					case Module(c):
						stackLabelArr.push('Module ${c}');
					case FilePos(parent, file, line, col):
						switch (parent)
						{
							case Method(cla, func): stackLabelArr.push('${file.replace('.hx', '')}.$func() [line $line]');
							case _: stackLabelArr.push('${file.replace('.hx', '')} [line $line]');
						}
					case LocalFunction(v):
						stackLabelArr.push('Local Function ${v}');
					case Method(cl, m):
						stackLabelArr.push('${cl} - ${m}');
				}
			}
			stackLabel = stackLabelArr.join('\r\n');

			var crashReason = '';
			for (source => reason in commonCrashers) {
				if (stackLabel.contains(source)) {
					crashReason = reason;
					if (!extraLines.contains(crashReason)) extraLines.push(crashReason);
				}
			}
			
			if (stackLabel != null)
				for (line in extraLines)
					stackLabel += line;

			errorMessage += 'Uncaught Error: $m\n\n$stackLabel';

			// Mirror the crash into the vlog so the live session log carries
			// the same context as crash/; it flushes immediately because the
			// process may exit right after.
			try
			{
				VLog.crash(errorMessage, stackLabel);
			}
			catch (_:Dynamic) {}

			#if sys
			// The hardware information makes a bug report a lot more useful, but
			// it must never keep the crash log itself from being written.
			var systemInfo:String = 'System information unavailable.';
			try
			{
				systemInfo = Native.buildSystemInfo();
			}
			catch (e)
				systemInfo = 'System information unavailable.';

			var crashText:String = '$errorMessage\n\nCrash Happened on Phoenix Engine v${MainMenuState.phoenixEngineVersion} (JSE v${MainMenuState.psychEngineJSVersion})!\n\n$systemInfo';
			final safeCrashText:String = LogUtils.limitText(LogUtils.redact(crashText), CrashBundle.MAX_TEXT_BYTES);
			try
			{
				if (!LogUtils.saveLog(path, safeCrashText))
					trace('Couldn\'t save error message.');
			}
			catch (_:Dynamic)
				trace('Couldn\'t save error message.');

			// Crash bundle (.zip): crash text + modsList.txt + each mod's
			// pack.json + prefs + screenshot, written next to the log. On
			// Android the crash/ folder is the SAF "Crash Logs" root, and the
			// crash screen can also save the bundle anywhere through the SAF
			// picker. Must never interfere with the log or the crash screen.
			try
			{
				CrashBundle.onCrash(safeCrashText, path);
			}
			catch (e:Dynamic) {}

			#if android
			// Opt-in event notification (Options -> Mobile Options -> "Event
			// Notifications"). Must never interfere with crash handling.
			try
			{
				var notice:String = 'Saved to $path';
				if (CrashBundle.lastBundleName.length > 0)
					notice += ' (bundle: ${CrashBundle.lastBundleName})';
				AndroidNotification.notifyEvent(AndroidNotification.ID_CRASH_LOG, 'Crash log saved', notice + ' - attach it when reporting this bug.');
			}
			catch (e:Dynamic) {}
			#end

			Sys.println(errorMessage);
			Sys.println("Crash dump saved in " + Path.normalize(path));
			if (CrashBundle.lastBundlePath.length > 0)
				Sys.println("Crash bundle saved in " + Path.normalize(CrashBundle.lastBundlePath));
			#end
		}
		catch (e:Dynamic)
			trace(e);

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = false;

		if (ClientPrefs.peOGCrash)
		{
			errorMessage += "\n\nPlease report this error to the GitHub page: https://github.com/havaianasdestruido/FNF-Phoenix-Engine"
				+ "\nThe engine has saved a crash log inside the crash folder, If you're making a GitHub issue you might want to send that!";
			if (CrashBundle.lastBundleName.length > 0)
				errorMessage += "\nA crash bundle (" + CrashBundle.lastBundleName + ") with your settings, mod list and a screenshot was saved next to it - even better for a report!";

			#if !flash
			CoolUtil.showPopUp(errorMessage,
				"Error! Phoenix Engine v"
				+ MainMenuState.phoenixEngineVersion
				+ " ("
				+ __superCoolErrorMessagesArray[FlxG.random.int(0, __superCoolErrorMessagesArray.length)]
				+ ")");

			lime.system.System.exit(1);
			#end
		}
		else
			FlxG.switchState(Crash.new);
	}

	private static function onError(message:Dynamic):Void
	{
		RecoveryBoot.markCrash();
		throw Std.string(message);
	}
}

@:access(CrashHandler)
class Crash extends MusicBeatState
{
	override public function create()
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF232323;
		add(bg);

		var ohNo:FlxText = new FlxText(0, 0, 1280, 'Phoenix Engine v${MainMenuState.phoenixEngineVersion} (JSE v${MainMenuState.psychEngineJSVersion}) has crashed!');
		ohNo.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo.alpha = 0;
		ohNo.screenCenter();
		ohNo.y = 14;
		add(ohNo);

		var ohNo2:FlxText = new FlxText(0, 0, 1280, CrashHandler.__superCoolErrorMessagesArray[FlxG.random.int(0, CrashHandler.__superCoolErrorMessagesArray.length)]);
		ohNo2.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo2.alpha = 0;
		ohNo2.screenCenter();
		ohNo2.y = 64;
		add(ohNo2);

		var ohNo3:FlxText = new FlxText(0, 0, 1280, "Crash Handler by YoshiCrafter29 and MAJigsaw77\nCrash UI State by Nael2xd");
		ohNo3.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE);
		ohNo3.alpha = 0;
		ohNo3.screenCenter();
		ohNo3.y = 580;
		ohNo3.x = 30;
		add(ohNo3);

		var ohNo4:FlxText = new FlxText(0, 0, 1280,
			#if mobile
			"Tap EXPORT CRASH BUNDLE to save the .zip somewhere you can reach (e.g. Downloads),\nthen attach it to your bug report. Tap RESTART to go back to the menu."
			#else
			"A crash bundle (.zip) with the log, your settings, mod list and a screenshot was\nsaved in the crash/ folder. Press [E] to save it elsewhere, or [F2] to screenshot this error."
			#end);
		ohNo4.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, FlxTextAlign.CENTER);
		ohNo4.alpha = 0;
		ohNo4.screenCenter();
		ohNo4.y = 620;
		add(ohNo4);

		// Status line for the bundle export (path, cancel, errors).
		bundleStatus = new FlxText(0, 0, 1280, '');
		bundleStatus.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, FlxTextAlign.CENTER);
		bundleStatus.alpha = 0;
		bundleStatus.screenCenter();
		bundleStatus.y = 486;
		add(bundleStatus);

		// The export button works with mouse/touch on every file target; on
		// mobile there is no keyboard, so a restart button is added too.
		#if sys
		#if mobile
		exportButton = makeButton(70, 520, 560, 56, 'EXPORT CRASH BUNDLE (.ZIP)');
		restartButton = makeButton(650, 520, 560, 56, 'RESTART');
		#else
		exportButton = makeButton(360, 520, 560, 56, 'EXPORT CRASH BUNDLE (.ZIP)  [E]');
		#end
		#end

		var stripClub:Array<String> = CrashHandler.errorMessage.split("\n");
		var i:Int = -1;
		var crash:Array<FlxText> = [];

		for (line in stripClub)
		{
			i++;
			crash.push(new FlxText(180, 0, 1280, line));
			crash[i].setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.LEFT);
			crash[i].alpha = 0;
			crash[i].screenCenter();
			crash[i].x = 70;
			crash[i].y = 110 + (20 * i);
			add(crash[i]);
		}

		var tip:FlxText = new FlxText(180, 0, 1280, "Press any key to restart." + (CrashHandler.extraLines.length > 0 ? " (Press ENTER to Report This Bug)" : " You cannot report this issue."));
		tip.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, FlxTextAlign.CENTER);
		tip.alpha = 0;
		tip.screenCenter();
		tip.y = 670;
		add(tip);

		FlxTween.tween(ohNo, {alpha: 1}, 0.5);
		FlxTween.tween(ohNo2, {alpha: 1}, 0.5);
		FlxTween.tween(ohNo3, {alpha: 0.25}, 0.5);
		FlxTween.tween(ohNo4, {alpha: 1}, 0.5);
		FlxTween.tween(tip, {alpha: 1}, 0.5);
		for (spr in crash)
			FlxTween.tween(spr, {alpha: 1}, 0.5);

		var error:FlxSound = FlxG.sound.load(Paths.sound('error'));
		error.play();

		super.create();
	}

	// Do note that if you use "resetGame" js engine will be in a crash loop because music is missing.
	// Even with my coding skills and trying to make it work it just doesn't, i'm probably stupid.
	// Also yes i tried FlxG.sound.playMusic and yet it doesn't do what it's suppose to do.
	// -nael2xd
	var countDown:Int = 10;
	var clicked:Bool = false;

	var bundleStatus:FlxText = null;
	var exportButton:FlxSprite = null;
	var restartButton:FlxSprite = null;

	override public function update(elapsed:Float)
	{
		// Mouse/touch buttons. On mobile these are the only way forward (there
		// is no keyboard); on desktop the export button mirrors the [E] key.
		if (FlxG.mouse.justPressed && !clicked)
		{
			if (exportButton != null && FlxG.mouse.overlaps(exportButton))
				exportBundle();
			else if (restartButton != null && FlxG.mouse.overlaps(restartButton))
				restartToMenu();
		}

		if (FlxG.keys.justPressed.ANY && !clicked)
		{
			FlxTransitionableState.skipNextTransIn = false;
			if (FlxG.keys.justPressed.ENTER && CrashHandler.extraLines.length < 1)
			{
				clicked = true;
				for (sprite in members)
					if (sprite is FlxSprite || sprite is FlxText)
						FlxTween.tween(sprite, {alpha: 0.5}, 0.5);
				var coolBg:FlxSprite = new FlxSprite().makeGraphic(840, 260, 0xFF404040);
				coolBg.screenCenter();
				add(coolBg);
				var coolInfo:FlxSprite = new FlxSprite().makeGraphic(830, 250, 0xFF636363);
				coolInfo.screenCenter();
				add(coolInfo);
				var heyText:FlxText = new FlxText(0, 0, 820,
					"Before you report the crash, Please check if one of those crash exists. If it does exist yet you make the issue, it will be marked as duplicate!");
				heyText.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				heyText.screenCenter();
				heyText.y -= 50;
				add(heyText);
				var countText:FlxText = new FlxText(0, 0, 640, "" + countDown);
				countText.setFormat(Paths.font('vcr.ttf'), 90, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				countText.screenCenter();
				countText.y += 73;
				add(countText);
				new FlxTimer().start(1, e ->
				{
					countDown--;
					countText.text = countDown + "";
					if (countDown == 0)
					{
						var issuesUrl:String = RuntimeFlags.url("urls.issues", "https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/new?template=bugs.yml");
						if (StringTools.endsWith(issuesUrl, "/issues")) issuesUrl += "/new?template=bugs.yml";
						CoolUtil.browserLoad(issuesUrl);
						FlxG.switchState(MainMenuState.new);
					}
				}, 10);
			}
			else if (FlxG.keys.justPressed.E)
				exportBundle();
			else if (!FlxG.keys.justPressed.F2)
				restartToMenu();
		}
	}

	function restartToMenu():Void
	{
		FlxTransitionableState.skipNextTransIn = false;
		Paths.playMenuMusic(true, 0);
		FlxG.switchState(MainMenuState.new);
	}

	function exportBundle():Void
	{
		if (CrashBundle.busy)
			return;
		setBundleStatus('Saving crash bundle...');
		CrashBundle.exportLastBundle(function(message:String):Void
		{
			setBundleStatus(message == null ? 'Export canceled.' : message);
		});
	}

	function setBundleStatus(message:String):Void
	{
		if (bundleStatus == null)
			return;
		bundleStatus.text = message;
		bundleStatus.alpha = 1;
	}

	function makeButton(x:Float, y:Float, width:Int, height:Int, label:String):FlxSprite
	{
		var button:FlxSprite = new FlxSprite(x, y).makeGraphic(width, height, 0xFF404040);
		add(button);
		var text:FlxText = new FlxText(x, y + (height - 22) / 2, width, label);
		text.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, FlxTextAlign.CENTER);
		add(text);
		return button;
	}
}
