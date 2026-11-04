package states;

import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.Paths;
import backend.PhoenixReleases.PhoenixRelease;
import backend.PhoenixVersion;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.util.FlxAxes;
import openfl.display.BlendMode;

import backend.Controls;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var release:PhoenixRelease;
	var warnText:FlxText;
	var changelog:FlxText;
	var changelogPanel:FlxSprite;
	var changelogCamera:FlxCamera;
	var updateText:FlxText;
	var checker:FlxBackdrop;
	var bg:FlxSprite;
	var scrollOffset:Float = 0;
	var maxScroll:Float = 0;
	var leaving:Bool = false;
	var layoutWidth:Int = 0;

	public function new(release:PhoenixRelease)
	{
		super();
		this.release = release;
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(bg, 1.1);
		if (warnText != null)
		{
			warnText.fieldWidth = FlxG.width;
			warnText.screenCenter(X);
		}
		layoutChangelog();
		if (updateText != null)
		{
			updateText.fieldWidth = FlxG.width - 20;
			updateText.y = FlxG.height - updateText.height - 12;
		}
		layoutWidth = FlxG.width;
	}

	override function create()
	{
		leftState = false;
		leaving = false;
		layoutWidth = FlxG.width;
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		MusicBeatState.windowNameSuffix2 = " (Outdated!)";

		super.create();

		bg = new FlxSprite(0, 0).loadGraphic(Paths.image("aboutMenu", "preload"));
		bg.color = 0xFFffd700;
		ViewportVisuals.cover(bg, 1.1);
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		checker = new FlxBackdrop(Paths.image('checker', 'preload'), FlxAxes.XY);
		checker.scale.set(4, 4);
		checker.color = 0xFFb8860b;
		checker.blend = BlendMode.LAYER;
		add(checker);
		checker.scrollFactor.set(0, 0.07);
		checker.alpha = 0.2;
		checker.updateHitbox();

		warnText = new FlxText(0, 10, FlxG.width,
			"A new Phoenix Engine update is available!\n"
			+ PhoenixVersion.display(PhoenixVersion.current) + "  ->  " + PhoenixVersion.display(release.version), 28);
		warnText.setFormat("VCR OSD Mono", 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warnText.screenCenter(X);
		add(warnText);

		changelogPanel = new FlxSprite();
		changelogPanel.makeGraphic(1, 1, 0xAA000000);
		add(changelogPanel);

		changelog = new FlxText(0, 0, 1040, release.changes, 16);
		changelog.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		changelog.wordWrap = true;
		changelogCamera = new FlxCamera();
		changelogCamera.bgColor = 0x00000000;
		FlxG.cameras.add(changelogCamera, false);
		changelog.cameras = [changelogCamera];
		add(changelog);

		updateText = new FlxText(10, 10, FlxG.width - 20,
			(mobile.MobileControls.enabled ? "Press A to update, B to ignore. Use UP/DOWN to read the changelog."
				: "SPACE/ENTER: update  |  ESC: ignore  |  UP/DOWN or mouse wheel: read the changelog."), 20);
		updateText.setFormat("VCR OSD Mono", 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(updateText);

		layoutChangelog();
		updateText.y = FlxG.height - updateText.height - 12;

		addVirtualPad(UP_DOWN, A_B);
		addVirtualPadCamera();
	}

	function layoutChangelog():Void
	{
		if (changelog == null || changelogPanel == null || changelogCamera == null) return;
		final left:Float = ScreenLayout.contentLeft(FlxG.width) + 100;
		final top:Float = warnText == null ? 130 : warnText.y + warnText.height + 16;
		final width:Int = Std.int(Math.min(1080, FlxG.width - 200));
		final footerTop:Float = updateText == null ? FlxG.height - 70 : FlxG.height - 80;
		final height:Int = Std.int(Math.max(120, footerTop - top - 12));
		changelogPanel.setPosition(left, top);
		changelogPanel.setGraphicSize(width, height);
		changelogPanel.updateHitbox();
		changelog.fieldWidth = width - 32;
		changelog.x = 16;
		changelog.y = 12;
		changelogCamera.setPosition(Std.int(left), Std.int(top));
		changelogCamera.setSize(width, height);
		maxScroll = Math.max(0, changelog.height + 24 - height);
		scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);
		changelogCamera.scroll.y = scrollOffset;
	}

	override function update(elapsed:Float)
	{
		checker.x += 0.45 / (ClientPrefs.framerate / 60);
		checker.y += 0.16 / (ClientPrefs.framerate / 60);

		if (!leaving)
		{
			var scrollDelta:Float = 0;
			if (controls.UI_UP) scrollDelta -= 420 * elapsed;
			if (controls.UI_DOWN) scrollDelta += 420 * elapsed;
			if (FlxG.mouse.wheel != 0) scrollDelta -= FlxG.mouse.wheel * 48;
			if (scrollDelta != 0 && maxScroll > 0)
			{
				scrollOffset = FlxMath.bound(scrollOffset + scrollDelta, 0, maxScroll);
				changelogCamera.scroll.y = scrollOffset;
			}

			if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || controls.ACCEPT)
			{
				CoolUtil.browserLoad(release.url);
				leave();
			}
			else if (controls.BACK)
			{
				leave();
			}
		}
		super.update(elapsed);
	}

	function leave():Void
	{
		if (leaving) return;
		leaving = true;
		leftState = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		var switched:Bool = false;
		for (item in members)
		{
			if (item == null) continue;
			FlxTween.tween(item, {alpha: 0}, 0.5, {
				onComplete: function(tween:FlxTween) {
					if (!switched && FlxG.state == this)
					{
						switched = true;
						FlxG.switchState(MainMenuState.new);
					}
				}
			});
		}
	}

	override function destroy():Void
	{
		MusicBeatState.windowNameSuffix2 = "";
		if (changelogCamera != null)
		{
			FlxG.cameras.remove(changelogCamera);
			changelogCamera = null;
		}
		super.destroy();
	}
}
