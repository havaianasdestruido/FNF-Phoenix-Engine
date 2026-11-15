package states;

import backend.Achievements;
import backend.ClientPrefs;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.DiscordClient;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.Paths;
import flixel.ui.FlxBar;
import flixel.util.FlxSort;
import objects.Alphabet;
import objects.AttachedSprite;
import objects.MovingCheckerboard;
import objects.TouchTarget;

import backend.Controls;

#if ACHIEVEMENTS_ALLOWED
class AchievementsMenuState extends MusicBeatState
{
	public var curSelected:Int = 0;

	public var options:Array<Dynamic> = [];
	public var grpOptions:FlxSpriteGroup;
	public var nameText:FlxText;
	public var descText:FlxText;
	public var progressTxt:FlxText;
	private var progressBarBG:AttachedSprite; //The image used for the health bar.
	public var progressBar:FlxBar;

	var camFollow:FlxObject;
	private var menuBackground:FlxSprite;
	private var achievementsBox:FlxSprite;
	private var detailsBox:FlxSprite;
	private var headerBg:FlxSprite;
	private var achTabBg:FlxSprite;
	private var achTabAccent:FlxSprite;
	private var achTabText:FlxText;
	private var statsTabBg:FlxSprite;
	private var statsTabText:FlxText;
	private var statsHintText:FlxText;
	private var layoutWidth:Int = 0;

	static inline final HEADER_HEIGHT:Int = 56;
	static inline final TAB_WIDTH:Int = 250;
	static inline final TAB_HEIGHT:Int = 38;
	static inline final TAB_GAP:Int = 16;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(menuBackground, 1.1);
		final shift:Float = (FlxG.width - layoutWidth) / 2;
		if (grpOptions != null) grpOptions.x += shift;
		if (achievementsBox != null) achievementsBox.screenCenter(X);
		if (detailsBox != null)
		{
			detailsBox.scale.set(FlxG.width, FlxG.height - detailsBox.y);
			detailsBox.updateHitbox();
		}
		for (text in [nameText, descText, progressTxt])
			if (text != null) text.fieldWidth = FlxG.width - 100;
		if (progressBar != null) progressBar.screenCenter(X);
		layoutHeader();
		layoutWidth = FlxG.width;
	}

	var MAX_PER_ROW:Int = 4;

	public var progressValue:Float = 0;

	override function create()
	{
		layoutWidth = FlxG.width;
		Paths.clearStoredMemory();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Achievements Menu", null);
		#end

		// prepare achievement list
		for (achievement => data in Achievements.achievements)
		{
			var unlocked:Bool = Achievements.isUnlocked(achievement);
			if(data.hidden != true || unlocked)
				options.push(makeAchievement(achievement, data, unlocked, data.mod));
		}

		// TO DO: check for mods

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		FlxG.camera.follow(camFollow, null, 0);
		FlxG.camera.scroll.y = -FlxG.height;

		menuBackground = new FlxSprite().loadGraphic(Paths.image('menuBGBlue'));
		menuBackground.antialiasing = ClientPrefs.globalAntialiasing;
		ViewportVisuals.cover(menuBackground, 1.1);
		menuBackground.scrollFactor.set();
		add(menuBackground);
		add(new MovingCheckerboard(0xFF5AB6E1, -18, -12));

		grpOptions = new FlxSpriteGroup();
		grpOptions.scrollFactor.x = 0;

		options.sort(sortByID);
		for (option in options)
		{
			var hasAntialias:Bool = ClientPrefs.globalAntialiasing;
			var graphic = null;
			if(option.unlocked)
			{
				#if MODS_ALLOWED Mods.currentModDirectory = option.mod; #end
				var image:String = 'achievements/' + option.name;
				if(Paths.fileExists('images/$image-pixel.png', IMAGE))
				{
					graphic = Paths.image('$image-pixel');
					hasAntialias = false;
				}
				else graphic = Paths.image(image);

				if(graphic == null) graphic = Paths.image('unknownMod');
			}
			else graphic = Paths.image('achievements/lockedachievement');

			var spr:FlxSprite = new FlxSprite(0, Math.floor(grpOptions.members.length / MAX_PER_ROW) * 180).loadGraphic(graphic);
			spr.scrollFactor.x = 0;
			spr.screenCenter(X);
			spr.x += 180 * ((grpOptions.members.length % MAX_PER_ROW) - MAX_PER_ROW/2) + spr.width / 2 + 15;
			spr.ID = grpOptions.members.length;
			spr.antialiasing = hasAntialias;
			grpOptions.add(spr);
		}
		#if MODS_ALLOWED Mods.loadTopMod(); #end

		achievementsBox = new FlxSprite(0, -30).makeGraphic(1, 1, FlxColor.BLACK);
		achievementsBox.scale.set(grpOptions.width + 60, grpOptions.height + 60);
		achievementsBox.updateHitbox();
		achievementsBox.alpha = 0.6;
		achievementsBox.scrollFactor.x = 0;
		achievementsBox.screenCenter(X);
		add(achievementsBox);
		add(grpOptions);

		detailsBox = new FlxSprite(0, 570).makeGraphic(1, 1, FlxColor.BLACK);
		detailsBox.scale.set(FlxG.width, FlxG.height - detailsBox.y);
		detailsBox.updateHitbox();
		detailsBox.alpha = 0.6;
		detailsBox.scrollFactor.set();
		add(detailsBox);

		nameText = new FlxText(50, detailsBox.y + 10, FlxG.width - 100, "", 32);
		nameText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		nameText.scrollFactor.set();

		descText = new FlxText(50, nameText.y + 38, FlxG.width - 100, "", 24);
		descText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();

		progressBarBG = new AttachedSprite('healthBar');
		progressBarBG.screenCenter(X);
		progressBarBG.y = descText.y + 52;
		progressBarBG.xAdd = -4;
		progressBarBG.yAdd = -4;

		progressBar = new FlxBar(progressBarBG.x + 4, progressBarBG.y + 4, LEFT_TO_RIGHT, Std.int(progressBarBG.width - 8), Std.int(progressBarBG.height - 8), this, 'progressValue');
		progressBar.scrollFactor.set();
		insert(members.indexOf(progressBarBG), progressBar);
		progressBarBG.sprTracker = progressBar;
		progressBar.visible = progressBarBG.visible = false;
		progressBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);

		progressTxt = new FlxText(50, progressBar.y - 6, FlxG.width - 100, "", 32);
		progressTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		progressTxt.scrollFactor.set();
		progressTxt.borderSize = 2;

		for (i in [progressBarBG, progressBar, progressTxt, descText, nameText])
			add(i);

		buildHeader();
		layoutHeader();

		_changeSelection();

		addVirtualPad(LEFT_FULL, A_B_C);

		Paths.clearUnusedMemory();
		super.create();

		FlxG.camera.follow(camFollow, null, 9);
		FlxG.camera.scroll.y = -FlxG.height;
	}

	function buildHeader():Void
	{
		headerBg = new FlxSprite(0, 0).makeGraphic(1, 1, 0xAA000000);
		headerBg.scrollFactor.set(0, 0);
		add(headerBg);

		achTabBg = new FlxSprite(0, 9).makeGraphic(1, 1, 0xFF1F4E79);
		achTabBg.scrollFactor.set(0, 0);
		add(achTabBg);

		achTabAccent = new FlxSprite(0, 9 + TAB_HEIGHT - 3).makeGraphic(1, 1, 0xFF5CE1E6);
		achTabAccent.scrollFactor.set(0, 0);
		add(achTabAccent);

		achTabText = new FlxText(0, 15, TAB_WIDTH, 'ACHIEVEMENTS', 22);
		achTabText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		achTabText.borderSize = 1.5;
		achTabText.scrollFactor.set(0, 0);
		add(achTabText);

		statsTabBg = new FlxSprite(0, 9).makeGraphic(1, 1, 0x77192838);
		statsTabBg.scrollFactor.set(0, 0);
		add(statsTabBg);

		statsTabText = new FlxText(0, 15, TAB_WIDTH, 'PLAYER STATS', 22);
		statsTabText.setFormat(Paths.font('vcr.ttf'), 22, 0xFFB8C7D6, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statsTabText.borderSize = 1.5;
		statsTabText.scrollFactor.set(0, 0);
		add(statsTabText);

		final hint:String = mobile.MobileControls.enabled ? 'A / TAP: Stats' : 'TAB / ENTER: Stats';
		statsHintText = new FlxText(0, 19, 240, hint, 16);
		statsHintText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB8C7D6, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statsHintText.borderSize = 1;
		statsHintText.scrollFactor.set(0, 0);
		add(statsHintText);
	}

	function layoutHeader():Void
	{
		if (headerBg != null)
		{
			headerBg.setPosition(0, 0);
			headerBg.setGraphicSize(FlxG.width, HEADER_HEIGHT);
			headerBg.updateHitbox();
		}

		final totalTabsWidth:Float = TAB_WIDTH * 2 + TAB_GAP;
		final startX:Float = Math.round((FlxG.width - totalTabsWidth) * 0.5);
		if (achTabBg != null)
		{
			achTabBg.setPosition(startX, 9);
			achTabBg.setGraphicSize(TAB_WIDTH, TAB_HEIGHT);
			achTabBg.updateHitbox();
		}
		if (achTabAccent != null)
		{
			achTabAccent.setPosition(startX, 9 + TAB_HEIGHT - 3);
			achTabAccent.setGraphicSize(TAB_WIDTH, 3);
			achTabAccent.updateHitbox();
		}
		if (achTabText != null)
		{
			achTabText.setPosition(startX, 15);
			achTabText.fieldWidth = TAB_WIDTH;
		}

		final statsX:Float = startX + TAB_WIDTH + TAB_GAP;
		if (statsTabBg != null)
		{
			statsTabBg.setPosition(statsX, 9);
			statsTabBg.setGraphicSize(TAB_WIDTH, TAB_HEIGHT);
			statsTabBg.updateHitbox();
		}
		if (statsTabText != null)
		{
			statsTabText.setPosition(statsX, 15);
			statsTabText.fieldWidth = TAB_WIDTH;
		}
		if (statsHintText != null)
		{
			final rightSpace:Float = FlxG.width - (statsX + TAB_WIDTH) - 24;
			statsHintText.visible = rightSpace >= 160;
			if (statsHintText.visible)
			{
				statsHintText.fieldWidth = Math.min(240, rightSpace);
				statsHintText.setPosition(FlxG.width - statsHintText.fieldWidth - 16, 19);
			}
		}
	}

	override function closeSubState()
	{
		if (virtualPad != null) virtualPad.visible = mobile.MobileControls.enabled;
		super.closeSubState();
	}

	function makeAchievement(achievement:String, data:Achievement, unlocked:Bool, mod:String = null)
	{
		var unlocked:Bool = Achievements.isUnlocked(achievement);
		return {
			name: achievement,
			displayName: unlocked ? data.name : '???',
			description: data.description,
			curProgress: data.maxScore > 0 ? Achievements.getScore(achievement) : 0,
			maxProgress: data.maxScore > 0 ? data.maxScore : 0,
			decProgress: data.maxScore > 0 ? data.maxDecimals : 0,
			unlocked: unlocked,
			ID: data.ID,
			mod: mod
		};
	}

	public static function sortByID(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.ID, Obj2.ID);

	var goingBack:Bool = false;
	override function update(elapsed:Float) {
		#if !FLX_NO_MOUSE
		if (!FlxG.mouse.visible && !backend.TouchlessUI.isActive()
			&& (Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10))
			FlxG.mouse.visible = true;
		#end

		if (!goingBack && (FlxG.keys.justPressed.TAB || controls.ACCEPT
			|| (statsTabBg != null && TouchTarget.justPressedOver(statsTabBg))))
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			FlxG.switchState(() -> new StatsState(true));
			goingBack = true;
			super.update(elapsed);
			return;
		}

		if(!goingBack && options.length > 1)
		{
			var add:Int = 0;
			if (controls.UI_LEFT_P) add = -1;
			else if (controls.UI_RIGHT_P) add = 1;

			if(add != 0)
			{
				var oldRow:Int = Math.floor(curSelected / MAX_PER_ROW);
				var rowSize:Int = Std.int(Math.min(MAX_PER_ROW, options.length - oldRow * MAX_PER_ROW));

				curSelected += add;
				var curRow:Int = Math.floor(curSelected / MAX_PER_ROW);
				if(curSelected >= options.length) curRow++;

				if(curRow != oldRow)
				{
					if(curRow < oldRow) curSelected += rowSize;
					else curSelected = curSelected -= rowSize;
				}
				_changeSelection();
			}

			if(options.length > MAX_PER_ROW)
			{
				var add:Int = 0;
				if (controls.UI_UP_P) add = -1;
				else if (controls.UI_DOWN_P) add = 1;

				if(add != 0)
				{
					var diff:Int = curSelected - (Math.floor(curSelected / MAX_PER_ROW) * MAX_PER_ROW);
					curSelected += add * MAX_PER_ROW;
					//trace('Before correction: $curSelected');
					if(curSelected < 0)
					{
						curSelected += Math.ceil(options.length / MAX_PER_ROW) * MAX_PER_ROW;
						if(curSelected >= options.length) curSelected -= MAX_PER_ROW;
						//trace('Pass 1: $curSelected');
					}
					if(curSelected >= options.length)
					{
						curSelected = diff;
						//trace('Pass 2: $curSelected');
					}

					_changeSelection();
				}
			}

			if((controls.RESET || virtualPad.buttonC.justPressed) && (options[curSelected].unlocked || options[curSelected].curProgress > 0))
			{
				if (virtualPad != null) virtualPad.visible = false;
				openSubState(new ResetAchievementSubstate());
			}
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
			goingBack = true;
		}
		super.update(elapsed);
	}

	public var barTween:FlxTween = null;
	function _changeSelection()
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		var hasProgress = options[curSelected].maxProgress > 0;
		nameText.text = options[curSelected].displayName;
		descText.text = options[curSelected].description;
		progressTxt.visible = progressBarBG.visible = progressBar.visible = hasProgress;

		if(barTween != null) barTween.cancel();

		if(hasProgress)
		{
			var val1:Float = options[curSelected].curProgress;
			var val2:Float = options[curSelected].maxProgress;
			progressTxt.text = CoolUtil.floorDecimal(val1, options[curSelected].decProgress) + ' / ' + CoolUtil.floorDecimal(val2, options[curSelected].decProgress);

			barTween = FlxTween.num(progressValue, (val1 / val2) * 100, 0.5, {ease: FlxEase.quadOut,
				onUpdate: function(twn:FlxTween) {
					var barValue = FlxMath.lerp(progressValue, (val1 / val2) * 100, twn.percent);
					if (barValue != 0)
						progressValue = barValue;
				}
			});
		}
		else progressValue = 0;

		var maxRows = Math.floor(grpOptions.members.length / MAX_PER_ROW);
		if(maxRows > 0)
		{
			var camY:Float = FlxG.height / 2 + (Math.floor(curSelected / MAX_PER_ROW) / maxRows) * Math.max(0, grpOptions.height - FlxG.height / 2 - 50) - 100;
			camFollow.setPosition(0, camY);
		}
		else camFollow.setPosition(0, grpOptions.members[curSelected].getGraphicMidpoint().y - 100);

		grpOptions.forEach(function(spr:FlxSprite) {
			spr.alpha = 0.6;
			if(spr.ID == curSelected) spr.alpha = 1;
		});
	}
}

class ResetAchievementSubstate extends MusicBeatSubstate
{
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;
	var background:FlxSprite;
	var heading:Alphabet;
	var achievementText:FlxText;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.fill(background);
		if (heading != null) heading.screenCenter(X);
		if (achievementText != null) achievementText.fieldWidth = FlxG.width - 100;
		if (yesText != null) { yesText.screenCenter(X); yesText.x -= 200; }
		if (noText != null) { noText.screenCenter(X); noText.x += 200; }
	}

	public function new()
	{
		super();

		background = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		ViewportVisuals.fill(background);
		background.alpha = 0;
		background.scrollFactor.set();
		add(background);
		FlxTween.tween(background, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

		heading = new Alphabet(0, 180, "Reset Achievement:", true);
		heading.screenCenter(X);
		heading.scrollFactor.set();
		add(heading);

		var state:AchievementsMenuState = cast FlxG.state;
		achievementText = new FlxText(50, heading.y + 90, FlxG.width - 100, state.options[state.curSelected].displayName, 40);
		achievementText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		achievementText.scrollFactor.set();
		achievementText.borderSize = 2;
		add(achievementText);

		yesText = new Alphabet(0, achievementText.y + 120, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		yesText.scrollFactor.set();
		for(letter in yesText.letters) letter.color = FlxColor.RED;
		add(yesText);
		noText = new Alphabet(0, achievementText.y + 120, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		noText.scrollFactor.set();
		add(noText);
		updateOptions();

		addVirtualPad(LEFT_RIGHT, A_B);
	}

	override function update(elapsed:Float)
	{
		if(controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		super.update(elapsed);

		if(controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			onYes = !onYes;
			updateOptions();
		}

		if(controls.ACCEPT)
		{
			if(onYes)
			{
				var state:AchievementsMenuState = cast FlxG.state;
				var option:Dynamic = state.options[state.curSelected];

				Achievements.variables.remove(option.name);
				Achievements.achievementsUnlocked.remove(option.name);
				option.unlocked = false;
				option.curProgress = 0;
				option.name = state.nameText.text = '???';
				if(option.maxProgress > 0) state.progressTxt.text = '0 / ' + option.maxProgress;
				state.grpOptions.members[state.curSelected].loadGraphic(Paths.image('achievements/lockedachievement'));
				state.grpOptions.members[state.curSelected].antialiasing = ClientPrefs.globalAntialiasing;

				if(state.progressBar.visible)
				{
					if(state.barTween != null) state.barTween.cancel();
					state.barTween = FlxTween.num(state.progressValue, 0, 0.5, {ease: FlxEase.quadOut,
					onUpdate: function(twn:FlxTween) {
						var barValue = FlxMath.lerp(state.progressValue, 0, twn.percent);
						if (barValue != 0)
							state.progressValue = barValue;
					}
					});
				}
				Achievements.save();
				FlxG.save.flush();

				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
			close();
			return;
		}
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}
#end
