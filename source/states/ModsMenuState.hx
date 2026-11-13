package states;

import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.DiscordClient;
import backend.MusicBeatState;
import backend.Paths;
import flixel.ui.FlxButton;
import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import openfl.geom.Rectangle;
import lime.utils.Assets;
import haxe.Json;

import flixel.util.FlxSpriteUtil;
// import options.ModSettingsSubState;
import flixel.addons.transition.FlxTransitionableState;
import haxe.io.Bytes;
import mobile.files.MobileFilePicker;
import mobile.files.ModZipInstaller;
import objects.Alphabet;
import objects.MovingCheckerboard;
import objects.Prompt;

import backend.Controls;
import headers.States;

#if MODS_ALLOWED
class ModsMenuState extends MusicBeatState
{
	var bg:FlxSprite;
	var icon:FlxSprite;
	var modName:Alphabet;
	var modDesc:FlxText;
	var modRestartText:FlxText;
	var modsList:ModsList = null;

	var bgList:FlxSprite;
	var buttonReload:MenuButton;
	var buttonImport:MenuButton;
	//var buttonModFolder:MenuButton;
	var buttonEnableAll:MenuButton;
	var buttonDisableAll:MenuButton;

	/** `true` while a `.zip` pick/extract round-trip is in flight. */
	var importingMod:Bool = false;
	/** Progress line shown while an archive is inspected/extracted. */
	var installText:FlxText;
	/** Auto-hides a failure message shown through {@link installText}. */
	var installStatusTimer:FlxTimer;
	var buttons:Array<MenuButton> = [];
	var settingsButton:MenuButton;

	var bgTitle:FlxSprite;
	var bgDescription:FlxSprite;
	var bgButtons:FlxSprite;

	var modsGroup:FlxTypedGroup<ModItem>;
	var curSelectedMod:Int = 0;
	
	var hoveringOnMods:Bool = true;
	var curSelectedButton:Int = 0; ///-1 = Enable/Disable All, -2 = Reload
	var modNameInitialY:Float = 0;

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;

	var startMod:String = null;
	var layoutWidth:Int = ScreenLayout.BASE_WIDTH;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(bg);
		final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
		if (shift != 0)
		{
			for (sprite in [bgList, bgTitle, bgDescription, bgButtons, icon, modName,
				modDesc, modRestartText, noModsTxt, buttonReload, buttonEnableAll, buttonDisableAll, buttonImport])
				if (sprite != null) sprite.x += shift;
			for (button in buttons) button.x += shift;
			if (modsGroup != null && modsGroup.length > 0) updateItemPositions();
		}
		if (noModsTxt != null)
			noModsTxt.fieldWidth = ScreenLayout.contentLeft(FlxG.width) + ScreenLayout.BASE_WIDTH - noModsTxt.x - 20;
		layoutWidth = FlxG.width;
	}

	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}
	override function create()
	{
		Paths.clearStoredMemory();
		persistentUpdate = false;

		modsList = Mods.parseList();
		Mods.currentModDirectory = modsList.all[0] != null ? modsList.all[0] : '';

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF665AFF;
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		ViewportVisuals.cover(bg);
		add(bg);
		add(new MovingCheckerboard(0xFF83EFD0, -18, -12));

		bgList = FlxSpriteUtil.drawRoundRect(new FlxSprite(40, 40).makeGraphic(340, 440, FlxColor.TRANSPARENT), 0, 0, 340, 440, 15, 15, FlxColor.BLACK);
		bgList.alpha = 0.6;

		modsGroup = new FlxTypedGroup<ModItem>();

		for (i => mod in modsList.all)
		{
			if(startMod == mod) curSelectedMod = i;

			var modItem:ModItem = new ModItem(mod);
			if(modsList.disabled.contains(mod))
			{
				modItem.icon.color = 0xFFFF6666;
				modItem.text.color = FlxColor.GRAY;
			}
			modsGroup.add(modItem);
		}

		var mod:ModItem = modsGroup.members[curSelectedMod];
		if(mod != null) bg.color = mod.bgColor;

		//
		var buttonX = bgList.x;
		var buttonWidth = Std.int(bgList.width);
		var buttonHeight = 80;

		buttonReload = new MenuButton(buttonX, bgList.y + bgList.height + 20, buttonWidth, buttonHeight, "RELOAD", null, function() reload());
		add(buttonReload);
		
		var myY = buttonReload.y + buttonReload.bg.height + 20;

		buttonEnableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "ENABLE ALL", null, function() {
			buttonEnableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.disabled.contains(mod.folder))
				{
					modsList.disabled.remove(mod.folder);
					modsList.enabled.push(mod.folder);
					mod.icon.color = FlxColor.WHITE;
					mod.text.color = FlxColor.WHITE;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonEnableAll.bg.color = FlxColor.GREEN;
		buttonEnableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonEnableAll.bg.color = FlxColor.GREEN;
		add(buttonEnableAll);

		buttonDisableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "DISABLE ALL", null, function() {
			buttonDisableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.enabled.contains(mod.folder))
				{
					modsList.enabled.remove(mod.folder);
					modsList.disabled.push(mod.folder);
					mod.icon.color = 0xFFFF6666;
					mod.text.color = FlxColor.GRAY;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonDisableAll.bg.color = 0xFFFF6666;
		buttonDisableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonDisableAll.bg.color = 0xFFFF6666;
		add(buttonDisableAll);
		checkToggleButtons();

		addVirtualPad(LEFT_FULL, A_B);

		if(modsList.all.length < 1)
		{
			buttonDisableAll.visible = buttonDisableAll.enabled = false;
			buttonEnableAll.visible = true;

			var myX = bgList.x + bgList.width + 20;
			noModsTxt = new FlxText(myX, 0, FlxG.width - myX - 20, "NO MODS INSTALLED\nPRESS BACK TO EXIT OR IMPORT A MOD .ZIP", 48);
			if(FlxG.random.bool(0.1)) noModsTxt.text += '\nBITCH.'; //meanie
			noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);

			var txt = new FlxText(bgList.x + 15, bgList.y + 15, bgList.width - 30, "No Mods found.", 16);
			txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE);
			add(txt);

			// Installing from a .zip is the only practical way in on a phone
			// without a file manager, so the empty list offers it front and center.
			var importWidth:Int = 360;
			buttonImport = new MenuButton(myX + ((FlxG.width - myX - 20) - importWidth) * 0.5, FlxG.height - 170,
				importWidth, 80, "IMPORT .ZIP", null, importModFromZip);
			add(buttonImport);

			FlxG.autoPause = false;
			changeSelectedMod();
			Paths.clearUnusedMemory();
			super.create();
			onResize(FlxG.width, FlxG.height);
			return;
		}

		bgTitle = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgList.x + bgList.width + 20, 40).makeGraphic(840, 180, FlxColor.TRANSPARENT), 0, 0, 840, 180, 15, 15, 0, 0, FlxColor.BLACK);
		bgTitle.alpha = 0.6;
		add(bgTitle);

		icon = new FlxSprite(bgTitle.x + 15, bgTitle.y + 15);
		add(icon);

		modNameInitialY = icon.y + 80;
		modName = new Alphabet(icon.x + 165, modNameInitialY, "", true);
		modName.scaleY = 0.8;
		add(modName);

		bgDescription = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgTitle.x, bgTitle.y + 200).makeGraphic(840, 450, FlxColor.TRANSPARENT), 0, 0, 840, 450, 0, 0, 15, 15, FlxColor.BLACK);
		bgDescription.alpha = 0.6;
		add(bgDescription);
		
		modDesc = new FlxText(bgDescription.x + 15, bgDescription.y + 15, bgDescription.width - 30, "", 24);
		modDesc.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
		add(modDesc);

		var myHeight = 100;
		modRestartText = new FlxText(bgDescription.x + 15, bgDescription.y + bgDescription.height - myHeight - 25, bgDescription.width - 30, "* Moving or Toggling On/Off this Mod will restart the game.", 16);
		modRestartText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT);
		add(modRestartText);

		bgButtons = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgDescription.x, bgDescription.y + bgDescription.height - myHeight).makeGraphic(840, myHeight, FlxColor.TRANSPARENT), 0, 0, 840, myHeight, 0, 0, 15, 15, FlxColor.WHITE);
		bgButtons.color = FlxColor.BLACK;
		bgButtons.alpha = 0.2;
		add(bgButtons);

		// Left half of the button strip is free: use it for the .zip importer.
		buttonImport = new MenuButton(bgButtons.x + 10, bgButtons.y + 10, 290, 80, "IMPORT", null, importModFromZip);
		add(buttonImport);

		var buttonsX = bgButtons.x + 320;
		var buttonsY = bgButtons.y + 10;

		var button = new MenuButton(buttonsX, buttonsY, 80, 80, null, Paths.image('modsMenuButtons', 'shared'), function() moveModToPosition(0), 54, 54); //Move to the top
		button.icon.animation.add('icon', [0]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 100, buttonsY, 80, 80, null, Paths.image('modsMenuButtons', 'shared'), function() moveModToPosition(curSelectedMod - 1), 54, 54); //Move up
		button.icon.animation.add('icon', [1]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 200, buttonsY, 80, 80, null, Paths.image('modsMenuButtons', 'shared'), function() moveModToPosition(curSelectedMod + 1), 54, 54); //Move down
		button.icon.animation.add('icon', [2]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		if(modsList.all.length < 2)
		{
			for (button in buttons)
				button.enabled = false;
		}
		// not yet
		/*
		settingsButton = new MenuButton(buttonsX + 300, buttonsY, 80, 80, null, Paths.image('modsMenuButtons', 'shared'), function() //Settings
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null && curMod.settings != null && curMod.settings.length > 0)
			{
				openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name));
			}
		}, 54, 54);

		settingsButton.icon.animation.add('icon', [3]);
		settingsButton.icon.animation.play('icon', true);
		add(settingsButton);
		buttons.push(settingsButton);

		if(modsGroup.members[curSelectedMod].settings == null || modsGroup.members[curSelectedMod].settings.length < 1)
			settingsButton.enabled = false;
		*/

		var button = new MenuButton(buttonsX + 400, buttonsY, 80, 80, null, Paths.image('modsMenuButtons', 'shared'), function() //On/Off
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			var mod:String = curMod.folder;
			if(!modsList.disabled.contains(mod)) //Enable
			{
				modsList.enabled.remove(mod);
				modsList.disabled.push(mod);
			}
			else //Disable
			{
				modsList.disabled.remove(mod);
				modsList.enabled.push(mod);
			}
			curMod.icon.color = modsList.disabled.contains(mod) ? 0xFFFF6666 : FlxColor.WHITE;
			curMod.text.color = modsList.disabled.contains(mod) ? FlxColor.GRAY : FlxColor.WHITE;

			if(curMod.mustRestart) waitingToRestart = true;
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}, 54, 54);
		button.icon.animation.add('icon', [4]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		button.focusChangeCallback = function(focus:Bool) {
			if(!focus)
				button.bg.color = modsList.enabled.contains(modsGroup.members[curSelectedMod].folder) ? FlxColor.GREEN : 0xFFFF6666;
		};

		if(modsList.all.length < 1)
		{
			for (btn in buttons) btn.enabled = false;
			button.focusChangeCallback = null;
		}
		
		add(bgList);
		add(modsGroup);

		changeSelectedMod();
		Paths.clearUnusedMemory();
		super.create();
		onResize(FlxG.width, FlxG.height);
	}
	
	var nextAttempt:Float = 1;
	var holdingMod:Bool = false;
	var mouseOffsets:FlxPoint = new FlxPoint();
	var holdingElapsed:Float = 0;
	var gottaClickAgain:Bool = false;

	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		if(controls.BACK && hoveringOnMods)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			saveTxt();

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(waitingToRestart)
			{
				//MusicBeatState.switchState(new TitleState());
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				if(FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else LoadingState.loadAndSwitchState(MainMenuState.new, false);

			persistentUpdate = false;
			FlxG.autoPause = ClientPrefs.autoPause;
			FlxG.mouse.visible = false;
			return;
		}

		if(!backend.TouchlessUI.isActive() && (Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10))
		{
			if(!FlxG.mouse.visible) FlxG.mouse.visible = true;
		}

		if(controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		if(modsList.all.length > 0)
		{
			var lastMode = hoveringOnMods;
			if(hoveringOnMods)
			{
				if(modsList.all.length == 1)
				{
					if(controls.UI_DOWN_P)
						changeSelectedMod(1);
					else if(controls.UI_UP_P)
						changeSelectedMod(-1);
				}

				if(controls.ACCEPT && buttons.length > 0)
				{
					var toggleBtn = buttons[buttons.length - 1];
					if(toggleBtn != null && toggleBtn.enabled && toggleBtn.onClick != null)
						toggleBtn.onClick();
				}
			}

			if(modsList.all.length > 1)
			{
				if(FlxG.mouse.justPressed)
				{
					for (i in centerMod-2...centerMod+3)
					{
						var mod = modsGroup.members[i];
						if(mod != null && mod.visible && FlxG.mouse.overlaps(mod))
						{
							hoveringOnMods = true;
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							mouseOffsets.x = FlxG.mouse.x - mod.x;
							mouseOffsets.y = FlxG.mouse.y - mod.y;
							curSelectedMod = i;
							changeSelectedMod();
							break;
						}
					}
					hoveringOnMods = true;
					var button = getButton();
					button.ignoreCheck = button.onFocus = false;
					gottaClickAgain = false;
				}

				if(hoveringOnMods)
				{
					var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;
					if(controls.UI_DOWN_P)
						changeSelectedMod(shiftMult);
					else if(controls.UI_UP_P)
						changeSelectedMod(-shiftMult);
					else if(FlxG.mouse.wheel != 0)
						changeSelectedMod(-FlxG.mouse.wheel * shiftMult, true);
					else if(FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END ||
						FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					{
						if(FlxG.keys.justPressed.END || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) curSelectedMod = modsList.all.length-1;
						else curSelectedMod = 0;
						changeSelectedMod();
					}
					else if(controls.UI_UP || controls.UI_DOWN)
					{
						var lastHoldTime:Float = holdTime;
						holdTime += elapsed;
						if(holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8)) changeSelectedMod(shiftMult * (controls.UI_UP ? -1 : 1));
					}
					else if(FlxG.mouse.pressed && !gottaClickAgain)
					{
						var curMod:ModItem = modsGroup.members[curSelectedMod];
						if(curMod != null)
						{
							if(!holdingMod && FlxG.mouse.justMoved && FlxG.mouse.overlaps(curMod)) holdingMod = true;

							if(holdingMod)
							{
								var moved:Bool = false;
								for (i in centerMod-2...centerMod+3)
								{
									var mod = modsGroup.members[i];
									if(mod != null && mod.visible && FlxG.mouse.overlaps(mod) && curSelectedMod != i)
									{
										moveModToPosition(i);
										moved = true;
										break;
									}
								}
								
								if(!moved)
								{
									var factor:Float = -1;
									if(FlxG.mouse.y < bgList.y)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (bgList.y - FlxG.mouse.y) / 100)));
									else if(FlxG.mouse.y > bgList.y + bgList.height)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (FlxG.mouse.y - bgList.y - bgList.height) / 100)));
		
									if(factor >= 0)
									{
										holdingElapsed += elapsed;
										if(holdingElapsed >= factor)
										{
											holdingElapsed = 0;
											var newPos = curSelectedMod;
											if(FlxG.mouse.y < bgList.y) newPos--;
											else newPos++;
											moveModToPosition(Std.int(Math.max(0, Math.min(modsGroup.length - 1, newPos))));
										}
									}
								}
								curMod.x = FlxG.mouse.x - mouseOffsets.x;
								curMod.y = FlxG.mouse.y - mouseOffsets.y;
							}
						}
						
					}
					else if(FlxG.mouse.justReleased && holdingMod)
					{
						holdingMod = false;
						holdingElapsed = 0;
						updateItemPositions();
					}
				}
			}

			if(lastMode == hoveringOnMods)
			{
				if(hoveringOnMods)
				{
					if(controls.UI_RIGHT_P)
					{
						hoveringOnMods = false;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						curSelectedButton = firstEnabledButtonIndex();
						changeSelectedButton();
					}
				}
				else 
				{
					if(controls.BACK)
					{
						hoveringOnMods = true;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						changeSelectedMod();
					}
					else if(controls.ACCEPT)
					{
						var button = getButton();
						if(button.onClick != null) button.onClick();
					}
					else if(curSelectedButton < 0)
					{
						if(controls.UI_UP_P)
						{
							switch(curSelectedButton)
							{
								case -3:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
								case -2, -1:
									changeSelectedButton(-1);
							}
						}
						else if(controls.UI_DOWN_P)
						{
							switch(curSelectedButton)
							{
								case -3, -2:
									changeSelectedButton(1);
								case -1:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
							}
						}
						else if(controls.UI_RIGHT_P)
						{
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							curSelectedButton = firstEnabledButtonIndex();
							changeSelectedButton();
						}
					}
					else if(controls.UI_LEFT_P)
						changeSelectedButton(-1);
					else if(controls.UI_RIGHT_P)
						changeSelectedButton(1);
				}
			}
		}
		else
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);

			// Touch/gamepad shortcut for the only action available right now.
			if(controls.ACCEPT && !importingMod) importModFromZip();

			// Keep refreshing mods list every 2 seconds until you add a mod on the folder
			nextAttempt -= elapsed;
			if(nextAttempt < 0)
			{
				nextAttempt = 1;
				@:privateAccess
				Mods.updateModList();
				modsList = Mods.parseList();
				if(modsList.all.length > 0)
				{
					trace('mod(s) found! reloading');
					reload();
				}
			}
		}
		super.update(elapsed);
	}

	function firstEnabledButtonIndex():Int
	{
		for (i in 0...buttons.length)
			if (buttons[i] != null && buttons[i].enabled)
				return i;
		return -3;
	}

	function changeSelectedButton(add:Int = 0)
	{
		ModsMenuHelpers.changeSelectedButton(this, add);
	}

	function getButton()
	{
		return ModsMenuHelpers.getButton(this);
	}

	function changeSelectedMod(add:Int = 0, isMouseWheel:Bool = false)
	{
		ModsMenuHelpers.changeSelectedMod(this, add, isMouseWheel);
	}

	var colorTween:FlxTween = null;
	function updateModDisplayData()
	{
		ModsMenuHelpers.updateModDisplayData(this);
	}

	var centerMod:Int = 2;
	function updateItemPositions()
	{
		ModsMenuHelpers.updateItemPositions(this);
	}

	var waitingToRestart:Bool = false;
	function moveModToPosition(?mod:String = null, position:Int = 0)
	{
		ModsMenuHelpers.moveModToPosition(this, mod, position);
	}

	function checkToggleButtons()
	{
		ModsMenuHelpers.checkToggleButtons(this);
	}

	function reload(?selectMod:String = null)
	{
		ModsMenuHelpers.reload(this, selectMod);
	}
	
	function saveTxt()
	{
		ModsMenuHelpers.saveTxt(this);
	}

	/* ------------------------------------------------------------------
	 * Mod import (.zip)
	 * ------------------------------------------------------------------ */

	/**
	 * Opens the platform picker (SAF on Android, native dialog on desktop) and
	 * installs the selected `.zip` as a mod folder.
	 *
	 * This is the practical install path on a phone: the archive is extracted
	 * by `mobile.files.ModZipInstaller`, validated and only then enabled, and
	 * the mods list is reloaded so the new mod shows up immediately.
	 */
	public function importModFromZip():Void
	{
		if(importingMod) return;
		importingMod = true;

		var started:Bool = MobileFilePicker.openFile(function(file) {
			if(file == null)
			{
				importingMod = false; // canceled
				return;
			}
			installZip(file.data, file.name);
		}, ['zip'], 'Select a mod .zip');

		if(!started)
		{
			importingMod = false;
			showInstallError('This build cannot open a file picker, so mods cannot be imported here.');
		}
	}

	/** Reads archive metadata and asks before replacing an existing mod folder. */
	function installZip(data:Bytes, displayName:String):Void
	{
		if(data == null)
		{
			importingMod = false;
			showInstallError('The selected file could not be read.');
			return;
		}

		showInstallStatus('READING ARCHIVE...');
		new FlxTimer().start(0.1, function(timer:FlxTimer) {
			var inspection = ModZipInstaller.inspect(data, displayName, Paths.mods());
			if(!inspection.ok)
			{
				importingMod = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				showInstallError(inspection.error);
				return;
			}

			if(!inspection.conflicts)
			{
				finishInstall(data, displayName, false);
				return;
			}

			hideInstallStatus();
			FlxG.sound.play(Paths.sound('scrollMenu'));
			openSubState(new Prompt('The folder "mods/' + inspection.folder + '/" already exists.\n\nReplace it with this .zip?', 0,
				function() {
					finishInstall(data, displayName, true);
				}, function() {
					importingMod = false;
				}, false, null, null, true));
		});
	}

	/** Extracts, validates and enables the archive, then reloads the list. */
	function finishInstall(data:Bytes, displayName:String, replaceExisting:Bool):Void
	{
		showInstallStatus('INSTALLING MOD...');
		new FlxTimer().start(0.1, function(timer:FlxTimer) {
			var result = ModZipInstaller.importZip(data, displayName, Paths.mods(), null, validateModPack, replaceExisting);
			importingMod = false;
			hideInstallStatus();

			if(!result.ok)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				showInstallError(result.error);
				return;
			}

			if(!Mods.registerInstalledMod(result.folder))
				trace('The imported mod "${result.folder}" could not be enabled in modsList.txt.');

			// Keep the in-memory copy in sync so reload() -> saveTxt() writes it too.
			if(!modsList.all.contains(result.folder))
			{
				modsList.all.push(result.folder);
				modsList.enabled.push(result.folder);
				modsList.disabled.remove(result.folder);
			}

			hideInstallStatus();
			FlxG.sound.play(Paths.sound('confirmMenu'));
			reload(result.folder);
		});
	}

	/** `pack.json` validation for imported mods (comments/trailing commas allowed). */
	function validateModPack(text:String):Bool
	{
		try
		{
			var pack:Dynamic = tjson.TJSON.parse(text);
			return pack != null && !Std.isOfType(pack, Array);
		}
		catch(e:Dynamic)
		{
			return false;
		}
	}

	function showInstallStatus(text:String):Void
	{
		if(installText == null)
		{
			installText = new FlxText(0, 0, FlxG.width, '', 24);
			installText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			installText.borderSize = 2;
			add(installText);
		}

		installText.text = text;
		installText.visible = true;
		installText.screenCenter();
		installText.y = FlxG.height - 60;
	}

	/**
	 * Reports an import failure inside the state.
	 *
	 * A native alert is not guaranteed on every target (and blocks the game
	 * loop where it exists), so the message is drawn in the menu itself and
	 * only mirrored to a popup on desktop.
	 */
	function showInstallError(message:String):Void
	{
		var reason:String = message == null || message.length == 0 ? 'Unknown error.' : message;
		showInstallStatus('IMPORT FAILED\n' + reason);
		installText.screenCenter();

		#if !android
		CoolUtil.showPopUp(reason, 'Import mod failed');
		#end

		if(installStatusTimer != null) installStatusTimer.cancel();
		installStatusTimer = new FlxTimer().start(6, function(timer:FlxTimer) {
			installStatusTimer = null;
			hideInstallStatus();
		});
	}

	function hideInstallStatus():Void
	{
		if(installStatusTimer != null)
		{
			installStatusTimer.cancel();
			installStatusTimer = null;
		}

		if(installText != null) installText.visible = false;
	}
}

class ModItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;
	public var totalFrames:Int = 0;

	// options
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var bgColor:FlxColor = 0xFF665AFF;
	public var pack:Dynamic = null;
	public var folder:String = 'unknownMod';
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;

	public function new(folder:String)
	{
		super();

		this.folder = folder;
		pack = Mods.getPack(folder);
		/*
		var path:String = Paths.mods('$folder/data/settings.json');
		if(FileSystem.exists(path))
		{
			var data:String = File.getContent(path);
			try
			{
				//trace('trying to load settings: $folder');
				settings = tjson.TJSON.parse(data);
			}
			catch(e:Dynamic)
			{
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
				var errorMsg = 'An error occurred: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}
		*/
		selectBg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectBg.alpha = 0.8;
		selectBg.visible = false;
		add(selectBg);

		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.globalAntialiasing;
		add(icon);

		text = new FlxText(95, 38, 230, "", 16);
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		var isPixel = false;
		var bmp = Paths.cacheBitmap(Paths.mods('$folder/pack.png'));
		if(bmp == null)
		{
			bmp = Paths.cacheBitmap(Paths.mods('$folder/pack-pixel.png'));
			isPixel = true;
		}

		if(bmp != null)
		{
			icon.loadGraphic(bmp, true, 150, 150);
			if(isPixel) icon.antialiasing = false;
		}
		else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		icon.scale.set(0.5, 0.5);
		icon.updateHitbox();
		
		this.name = folder;
		if(pack != null)
		{
			if(pack.name != null) this.name = pack.name;
			if(pack.description != null) this.desc = pack.description;
			if(pack.iconFramerate != null) this.iconFps = pack.iconFramerate;
			if(pack.color != null)
			{
				this.bgColor = FlxColor.fromRGB(pack.color[0] != null ? pack.color[0] : 170,
				pack.color[1] != null ? pack.color[1] : 0,
				pack.color[2] != null ? pack.color[2] : 255);
			}
			this.mustRestart = (pack.restart == true);
		}
		text.text = this.name;

		if(bmp != null)
		{
			totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
			icon.animation.add("icon", [for (i in 0...totalFrames) i], iconFps);
			icon.animation.play("icon");
		}
		selectBg.scale.set(width + 5, height + 5);
		selectBg.updateHitbox();
	}
}

class MenuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var textOn:Alphabet;
	public var textOff:Alphabet;
	public var icon:FlxSprite;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;
	public function new(x:Float, y:Float, width:Int, height:Int, ?text:String = null, ?img:FlxGraphic = null, onClick:Void->Void = null, animWidth:Int = 0, animHeight:Int = 0)
	{
		super(x, y);
		
		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT), 0, 0, width, height, 15, 15, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		add(bg);

		if(text != null)
		{
			textOn = new Alphabet(0, 0, "", false);
			textOn.setScale(0.6);
			textOn.text = text;
			textOn.alpha = 0.6;
			textOn.visible = false;
			centerOnBg(textOn);
			textOn.y -= 30;
			add(textOn);
			
			textOff = new Alphabet(0, 0, "", true);
			textOff.setScale(0.52);
			textOff.text = text;
			textOff.alpha = 0.6;
			centerOnBg(textOff);
			add(textOff);
		}
		else if(img != null)
		{
			icon = new FlxSprite();
			if(animWidth > 0 || animHeight > 0) icon.loadGraphic(img, true, animWidth, animHeight);
			else icon.loadGraphic(img);
			centerOnBg(icon);
			add(icon);
		}

		this.onClick = onClick;
		setButtonVisibility(false);
	}

	public var focusChangeCallback:Bool->Void = null;
	public var onFocus(default, set):Bool = false;
	public var ignoreCheck:Bool = false;
	private var _needACheck:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!enabled)
		{
			onFocus = false;
			return;
		}

		if(!ignoreCheck && FlxG.mouse.justMoved && FlxG.mouse.visible)
			onFocus = FlxG.mouse.overlaps(this);

		if(onFocus && onClick != null && FlxG.mouse.justPressed)
			onClick();

		if(_needACheck)
		{
			_needACheck = false;
			setButtonVisibility(FlxG.mouse.overlaps(this));
		}
	}

	function set_onFocus(newValue:Bool)
	{
		var lastFocus:Bool = onFocus;
		onFocus = newValue;
		if(onFocus != lastFocus && enabled) setButtonVisibility(onFocus);
		return newValue;
	}

	function set_enabled(newValue:Bool)
	{
		enabled = newValue;
		setButtonVisibility(false);
		alpha = enabled ? 1 : 0.4;

		_needACheck = enabled;
		return newValue;
	}

	public function setButtonVisibility(focusVal:Bool)
	{
		alpha = 1;
		bg.color = focusVal ? FlxColor.WHITE : FlxColor.BLACK;
		bg.alpha = focusVal ? 0.8 : 0.6;

		var focusAlpha = focusVal ? 1 : 0.6;
		if(textOn != null && textOff != null)
		{
			textOn.alpha = textOff.alpha = focusAlpha;
			textOn.visible = focusVal;
			textOff.visible = !focusVal;
		}
		else if(icon != null)
		{
			icon.alpha = focusAlpha;
			icon.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}

		if(!enabled) alpha = 0.4;
		if(focusChangeCallback != null) focusChangeCallback(focusVal);
	}

	public function centerOnBg(spr:FlxSprite)
	{
		spr.x = bg.width/2 - spr.width/2;
		spr.y = bg.height/2 - spr.height/2;
	}
}
#else
class ModsMenuState extends MusicBeatState
{
	public function new() { super(); }
}
#end
