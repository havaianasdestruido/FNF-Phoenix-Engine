package editors;

import objects.ui.EditorTooltips;

import objects.ui.CustomFlxUI.CustomFlxUIInputText;
import objects.ui.CustomFlxUI.CustomFlxUINumericStepper;
import objects.ui.CustomFlxUI.CustomFlxUITabMenu;
import objects.ui.CustomFlxUI.CustomFlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import objects.FlxUIDropDownMenuCustom;

import backend.DiscordClient;
import backend.MusicBeatState;
import backend.Paths;
import data.StageData;
import data.StageEditorCore;
import data.StageUndoStack;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.graphics.FlxGraphic;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.ui.FlxButton;
import lime.system.Clipboard;
import mobile.files.MobileFilePicker;
import objects.Character;
import objects.Prompt;
import objects.StagePropSprite;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import states.TitleState;

import headers.Editors;

typedef StageEditorMeta =
{
	var data:Dynamic;
	var sprite:FlxSprite;
}

/**
 * Visual stage editor. Places characters, camera targets and JSON props
 * (`sprite` / `animatedSprite` / `square`) then writes the Psych 1.0 stage
 * format that `PlayStateStageObjects` spawns at runtime.
 */
class StageEditorState extends MusicBeatState
{
	/** File stem written on Save (`stage.json`). */
	public var stageName:String;
	/** Working copy of the Psych-compatible stage JSON. */
	public var stageJson:Dynamic;
	/** True after a change that has not been saved to disk. */
	public var unsavedProgress:Bool = false;
	/** Desktop save/load dialog; null while idle. */
	public var _file:FileReference;
	/** Preview girlfriend. */
	public var gf:Character;
	/** Preview opponent. */
	public var dad:Character;
	/** Preview boyfriend. */
	public var boyfriend:Character;

	var music:EditingMusic;
	var undo:StageUndoStack = new StageUndoStack();
	var metas:Array<StageEditorMeta> = [];
	var curSelected:Int = 0;
	var goToPlayState:Bool = false;

	var camEditor:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;

	var UI_box:CustomFlxUITabMenu;
	var listGroup:FlxTypedGroup<FlxText>;
	var listBg:FlxSprite;
	var listTitle:FlxText;
	var listScroll:Int = 0;
	var selectionSprites:FlxSpriteGroup = new FlxSpriteGroup();
	var createPopup:FlxSpriteGroup;
	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var posTxt:FlxText;
	var outputTxt:FlxText;
	var outputTime:Float = 0;
	var cameraPointer:FlxSprite;

	var stageDropDown:CustomFlxUIDropDownMenu;
	var nameInput:CustomFlxUIInputText;
	var directoryInput:CustomFlxUIInputText;
	var shadersInput:CustomFlxUIInputText;
	var zoomStepper:CustomFlxUINumericStepper;
	var speedStepper:CustomFlxUINumericStepper;
	var pixelCheck:FlxUICheckBox;
	var hideGfCheck:FlxUICheckBox;

	var gfNameInput:CustomFlxUIInputText;
	var dadNameInput:CustomFlxUIInputText;
	var bfNameInput:CustomFlxUIInputText;
	var gfXStepper:CustomFlxUINumericStepper;
	var gfYStepper:CustomFlxUINumericStepper;
	var dadXStepper:CustomFlxUINumericStepper;
	var dadYStepper:CustomFlxUINumericStepper;
	var bfXStepper:CustomFlxUINumericStepper;
	var bfYStepper:CustomFlxUINumericStepper;
	var gfCamXStepper:CustomFlxUINumericStepper;
	var gfCamYStepper:CustomFlxUINumericStepper;
	var dadCamXStepper:CustomFlxUINumericStepper;
	var dadCamYStepper:CustomFlxUINumericStepper;
	var bfCamXStepper:CustomFlxUINumericStepper;
	var bfCamYStepper:CustomFlxUINumericStepper;

	var objNameInput:CustomFlxUIInputText;
	var objImageInput:CustomFlxUIInputText;
	var objXStepper:CustomFlxUINumericStepper;
	var objYStepper:CustomFlxUINumericStepper;
	var objScaleXStepper:CustomFlxUINumericStepper;
	var objScaleYStepper:CustomFlxUINumericStepper;
	var objScrollXStepper:CustomFlxUINumericStepper;
	var objScrollYStepper:CustomFlxUINumericStepper;
	var objAlphaStepper:CustomFlxUINumericStepper;
	var objAngleStepper:CustomFlxUINumericStepper;
	var objDanceStepper:CustomFlxUINumericStepper;
	var objColorInput:CustomFlxUIInputText;
	var objFlipX:FlxUICheckBox;
	var objFlipY:FlxUICheckBox;
	var objAntialias:FlxUICheckBox;
	var objLow:FlxUICheckBox;
	var objHigh:FlxUICheckBox;
	var objStory:FlxUICheckBox;
	var objFreeplay:FlxUICheckBox;
	var objTypeTxt:FlxText;

	var animNameInput:CustomFlxUIInputText;
	var animSymbolInput:CustomFlxUIInputText;
	var animIndicesInput:CustomFlxUIInputText;
	var animFpsStepper:CustomFlxUINumericStepper;
	var animLoopCheck:FlxUICheckBox;
	var animListTxt:FlxText;

	var showLowQuality:FlxUICheckBox;
	var showHighQuality:FlxUICheckBox;
	var showStoryMode:FlxUICheckBox;
	var showFreeplayMode:FlxUICheckBox;
	var gridCheck:FlxUICheckBox;
	var snapToGrid:Bool = false;
	var focusTarget:String = 'boyfriend';

	var dragging:Bool = false;
	var ignoreUndo:Bool = false;
	var stageList:Array<String> = [];

	public function new(stageToLoad:String = 'stage', goToPlayState:Bool = false)
	{
		super();
		this.stageName = stageToLoad != null && stageToLoad.length > 0 ? stageToLoad : 'stage';
		this.goToPlayState = goToPlayState;
	}

	override function create()
	{
		music = new EditingMusic();
		camEditor = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Stage Editor', 'Stage: ' + stageName);
		#end

		var loaded = StageData.getStageFile(stageName);
		stageJson = loaded != null ? loaded : StageEditorCore.dummyStage();
		StageEditorCore.normalizeStage(stageJson);
		StageEditorCore.ensureCharacterSlots(stageJson);
		StageEditorHelpers.loadJsonDirectory(this);

		gf = makeCharacter(StageEditorHelpers.editorMetaName(stageJson, 'gf'), false);
		dad = makeCharacter(StageEditorHelpers.editorMetaName(stageJson, 'dad'), false);
		boyfriend = makeCharacter(StageEditorHelpers.editorMetaName(stageJson, 'boyfriend'), true);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		FlxG.camera.follow(camFollow, LOCKON, 1);
		FlxG.camera.zoom = StageEditorCore.clampZoom(stageJson.defaultZoom);

		cameraPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraPointer.setGraphicSize(40, 40);
		cameraPointer.updateHitbox();
		cameraPointer.alpha = 0.7;
		add(cameraPointer);

		for (i in 0...4)
		{
			var spr:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.LIME);
			spr.alpha = 0.85;
			selectionSprites.add(spr);
		}
		add(selectionSprites);

		rebuildWorld();
		focusOn('boyfriend');

		addHelpScreen();
		addHUD();
		addUI();
		addSpriteList();
		addCreatePopup();
		updateSpriteList();
		updateSelectedUI();
		refreshFilterPreview();
		pushUndo();

		FlxG.mouse.visible = true;
		super.create();
	}

	function makeCharacter(name:String, isPlayer:Bool):Character
	{
		var char:Character = new Character(0, 0, name, isPlayer);
		char.debugMode = true;
		return char;
	}

	function addHelpScreen()
	{
		var str:Array<String> = [
			'E/Q - Camera Zoom In/Out',
			'I/J/K/L or Right Mouse - Pan Camera',
			'R - Reset Camera Zoom',
			'Click / Arrows - Select and Move',
			'Hold Shift - Move 10x, Control - 1px',
			'G - Snap to ' + StageEditorCore.GRID_SIZE + 'px grid',
			'Mouse wheel on list - Scroll sprites',
			'',
			'Ctrl+S Export   Ctrl+Shift+S Save to Mod',
			'Ctrl+Z Undo   Ctrl+Y Redo',
			'F1 - Toggle this help   F12 - Selection box',
			'ESC - Back (warns if unsaved)'
		];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.65;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i in 0...str.length)
		{
			if (str[i].length < 1) continue;
			var helpText:FlxText = new FlxText(0, 0, 720, str[i], 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.scrollFactor.set();
			helpText.screenCenter();
			helpText.y += ((i - str.length / 2) * 28) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function addHUD()
	{
		var tip:FlxText = new FlxText(0, FlxG.height - 22, FlxG.width, 'Press F1 for Help', 16);
		tip.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		tip.cameras = [camHUD];
		tip.scrollFactor.set();
		add(tip);

		posTxt = new FlxText(0, 8, FlxG.width, '', 16);
		posTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		posTxt.cameras = [camHUD];
		posTxt.scrollFactor.set();
		add(posTxt);

		outputTxt = new FlxText(0, 40, FlxG.width, '', 20);
		outputTxt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		outputTxt.cameras = [camHUD];
		outputTxt.scrollFactor.set();
		outputTxt.alpha = 0;
		add(outputTxt);

		showStoryMode = new FlxUICheckBox(FlxG.width - 250, FlxG.height - 60, null, null, 'Story', 70);
		showStoryMode.cameras = [camHUD];
		showStoryMode.checked = true;
		showStoryMode.callback = refreshFilterPreview;
		add(showStoryMode);

		showFreeplayMode = new FlxUICheckBox(FlxG.width - 130, FlxG.height - 60, null, null, 'Freeplay', 80);
		showFreeplayMode.cameras = [camHUD];
		showFreeplayMode.checked = true;
		showFreeplayMode.callback = refreshFilterPreview;
		add(showFreeplayMode);

		showLowQuality = new FlxUICheckBox(FlxG.width - 250, FlxG.height - 36, null, null, 'Low Quality', 90);
		showLowQuality.cameras = [camHUD];
		showLowQuality.checked = false;
		showLowQuality.callback = refreshFilterPreview;
		add(showLowQuality);

		showHighQuality = new FlxUICheckBox(FlxG.width - 130, FlxG.height - 36, null, null, 'High Quality', 90);
		showHighQuality.cameras = [camHUD];
		showHighQuality.checked = true;
		showHighQuality.callback = refreshFilterPreview;
		add(showHighQuality);

		var dadBtn = new FlxButton(20, FlxG.height - 36, 'Opp Cam', function() focusOn('dad'));
		var bfBtn = new FlxButton(110, FlxG.height - 36, 'BF Cam', function() focusOn('boyfriend'));
		var gfBtn = new FlxButton(200, FlxG.height - 36, 'GF Cam', function() focusOn('gf'));
		for (btn in [dadBtn, bfBtn, gfBtn])
		{
			btn.cameras = [camHUD];
			add(btn);
		}
	}

	function addUI()
	{
		var tabs = [
			{name: 'Stage', label: 'Stage'},
			{name: 'Chars', label: 'Chars'},
			{name: 'Object', label: 'Object'},
			{name: 'Anims', label: 'Anims'}
		];
		UI_box = new CustomFlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camHUD];
		UI_box.resize(340, 400);
		UI_box.x = FlxG.width - 350;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		add(UI_box);

		addStageTab();
		addCharacterTab();
		addObjectTab();
		addAnimTab();
	}

	function addStageTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Stage';

		stageList = StageEditorHelpers.listStages();
		stageDropDown = new CustomFlxUIDropDownMenu(15, 30, FlxUIDropDownMenuCustom.makeStrIdLabelArray(stageList, true), function(id:String) {
			var name:String = stageList[Std.parseInt(id)];
			if (name != null) loadStageNamed(name);
		});
		stageDropDown.selectedLabel = stageName;

		nameInput = input(15, 70, 140, stageName);
		directoryInput = input(15, 110, 140, stageJson.directory);
		zoomStepper = stepper(180, 70, 0.05, stageJson.defaultZoom, 0.1, 3, 2);
		speedStepper = stepper(180, 110, 0.05, stageJson.camera_speed, 0.05, 10, 2);
		shadersInput = input(15, 150, 300, StageEditorCore.shadersToString(stageJson.shaders));

		pixelCheck = new FlxUICheckBox(15, 180, null, null, 'Pixel Stage', 100);
		pixelCheck.checked = stageJson.isPixelStage == true;
		pixelCheck.callback = function() {
			stageJson.isPixelStage = pixelCheck.checked;
			if (pixelCheck.checked && (stageJson.stageUI == null || stageJson.stageUI == '' || stageJson.stageUI == 'normal'))
				stageJson.stageUI = 'pixel';
			markDirty();
		};

		hideGfCheck = new FlxUICheckBox(150, 180, null, null, 'Hide GF', 80);
		hideGfCheck.checked = stageJson.hide_girlfriend == true;
		hideGfCheck.callback = function() {
			stageJson.hide_girlfriend = hideGfCheck.checked;
			StageEditorHelpers.repositionCharacters(this);
			markDirty();
		};

		var saveBtn = new FlxButton(15, 220, 'Save', saveStage);
		var loadBtn = new FlxButton(110, 220, 'Load File', loadStageFile);
		var newBtn = new FlxButton(205, 220, 'New', function() loadBlank(false));
		var week1Btn = new FlxButton(15, 250, 'Week 1 Template', function() loadBlank(true));
		var reloadBtn = new FlxButton(160, 250, 'Reload', function() loadStageNamed(stageName, true));
		var saveModBtn = new FlxButton(15, 280, 'Save to Mod', saveToMod);
		var copyBtn = new FlxButton(160, 280, 'Copy JSON', copyJson);
		gridCheck = new FlxUICheckBox(15, 310, null, null, 'Snap to Grid (' + StageEditorCore.GRID_SIZE + 'px)', 200);
		gridCheck.checked = snapToGrid;
		gridCheck.callback = function() {
			snapToGrid = gridCheck.checked;
		};

		tab.add(new FlxText(15, 12, 0, 'Stage:'));
		tab.add(new FlxText(15, 54, 0, 'Save name:'));
		tab.add(new FlxText(180, 54, 0, 'Zoom:'));
		tab.add(new FlxText(15, 94, 0, 'Asset directory:'));
		tab.add(new FlxText(180, 94, 0, 'Cam speed:'));
		tab.add(new FlxText(15, 134, 0, 'Shaders (comma separated):'));
		var stageWidgets:Array<Dynamic> = [
			nameInput, directoryInput, shadersInput, zoomStepper, speedStepper, pixelCheck,
			hideGfCheck, saveBtn, loadBtn, newBtn, week1Btn, reloadBtn, saveModBtn, copyBtn,
			gridCheck, stageDropDown
		];
		for (w in stageWidgets)
			tab.add(w);

		EditorTooltips.add(this, saveBtn, 'Export a JSON file through the system save dialog.');
		EditorTooltips.add(this, saveModBtn, 'Write stages/<name>.json into the active mod folder (or mods/stages/).');
		EditorTooltips.add(this, copyBtn, 'Copy the pretty-printed stage JSON to the clipboard.');
		EditorTooltips.add(this, gridCheck, 'Snap dragged and arrow-nudged positions to a ' + StageEditorCore.GRID_SIZE + 'px grid. G toggles this.');
		EditorTooltips.add(this, week1Btn, 'Start from the vanilla Week 1 layout as JSON props.');
		EditorTooltips.add(this, shadersInput, 'Shader names to compile on the loading screen, e.g. rain, glitch.');

		UI_box.addGroup(tab);
	}

	function addCharacterTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Chars';

		gfNameInput = input(15, 30, 100, StageEditorHelpers.editorMetaName(stageJson, 'gf'));
		dadNameInput = input(15, 70, 100, StageEditorHelpers.editorMetaName(stageJson, 'dad'));
		bfNameInput = input(15, 110, 100, StageEditorHelpers.editorMetaName(stageJson, 'boyfriend'));

		var reloadGf = new FlxButton(125, 28, 'Reload', function() reloadCharacter('gf', gfNameInput.text));
		var reloadDad = new FlxButton(125, 68, 'Reload', function() reloadCharacter('dad', dadNameInput.text));
		var reloadBf = new FlxButton(125, 108, 'Reload', function() reloadCharacter('boyfriend', bfNameInput.text));

		gfXStepper = stepper(15, 160, 10, 0, -9000, 9000, 0);
		gfYStepper = stepper(90, 160, 10, 0, -9000, 9000, 0);
		dadXStepper = stepper(15, 200, 10, 0, -9000, 9000, 0);
		dadYStepper = stepper(90, 200, 10, 0, -9000, 9000, 0);
		bfXStepper = stepper(15, 240, 10, 0, -9000, 9000, 0);
		bfYStepper = stepper(90, 240, 10, 0, -9000, 9000, 0);

		gfCamXStepper = stepper(180, 160, 10, 0, -9000, 9000, 0);
		gfCamYStepper = stepper(255, 160, 10, 0, -9000, 9000, 0);
		dadCamXStepper = stepper(180, 200, 10, 0, -9000, 9000, 0);
		dadCamYStepper = stepper(255, 200, 10, 0, -9000, 9000, 0);
		bfCamXStepper = stepper(180, 240, 10, 0, -9000, 9000, 0);
		bfCamYStepper = stepper(255, 240, 10, 0, -9000, 9000, 0);

		tab.add(new FlxText(15, 12, 0, 'GF / Dad / BF preview names'));
		tab.add(new FlxText(15, 142, 0, 'Position X/Y'));
		tab.add(new FlxText(180, 142, 0, 'Camera offset X/Y'));
		tab.add(new FlxText(15, 278, 200, 'GF, Dad, BF from top to bottom.'));
		var charWidgets:Array<Dynamic> = [
			gfNameInput, dadNameInput, bfNameInput, reloadGf, reloadDad, reloadBf,
			gfXStepper, gfYStepper, dadXStepper, dadYStepper, bfXStepper, bfYStepper,
			gfCamXStepper, gfCamYStepper, dadCamXStepper, dadCamYStepper, bfCamXStepper, bfCamYStepper
		];
		for (w in charWidgets)
			tab.add(w);

		UI_box.addGroup(tab);
	}

	function addObjectTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Object';

		objTypeTxt = new FlxText(15, 8, 300, 'Type: -');
		objNameInput = input(15, 40, 140, '');
		objImageInput = input(15, 80, 200, '');
		var reloadImg = new FlxButton(225, 78, 'Reload', function() {
			reloadSelectedImage();
		});

		objXStepper = stepper(15, 120, 10, 0, -20000, 20000, 1);
		objYStepper = stepper(90, 120, 10, 0, -20000, 20000, 1);
		objScaleXStepper = stepper(15, 160, 0.05, 1, 0.05, 50, 2);
		objScaleYStepper = stepper(90, 160, 0.05, 1, 0.05, 50, 2);
		objScrollXStepper = stepper(180, 120, 0.05, 1, -5, 5, 2);
		objScrollYStepper = stepper(255, 120, 0.05, 1, -5, 5, 2);
		objAlphaStepper = stepper(180, 160, 0.05, 1, 0, 1, 2);
		objAngleStepper = stepper(255, 160, 1, 0, -360, 360, 1);
		objDanceStepper = stepper(15, 200, 0.25, 0, 0, 16, 2);
		objColorInput = input(110, 200, 80, 'FFFFFF');

		objFlipX = new FlxUICheckBox(15, 240, null, null, 'Flip X', 70);
		objFlipX.callback = function() {
			var data = selectedData();
			if (data == null || StageEditorCore.isCharacterType(data.type)) return;
			data.flipX = objFlipX.checked;
			applySelectedVisual();
			markDirty();
		};
		objFlipY = new FlxUICheckBox(100, 240, null, null, 'Flip Y', 70);
		objFlipY.callback = function() {
			var data = selectedData();
			if (data == null || StageEditorCore.isCharacterType(data.type)) return;
			data.flipY = objFlipY.checked;
			applySelectedVisual();
			markDirty();
		};
		objAntialias = new FlxUICheckBox(185, 240, null, null, 'Antialiasing', 110);
		objAntialias.checked = true;
		objAntialias.callback = function() {
			var data = selectedData();
			if (data == null || StageEditorCore.isCharacterType(data.type)) return;
			data.antialiasing = objAntialias.checked;
			applySelectedVisual();
			markDirty();
		};
		objLow = new FlxUICheckBox(15, 270, null, null, 'Low Quality', 100);
		objLow.callback = function() {
			writeFiltersFromChecks();
			refreshFilterPreview();
			markDirty();
		};
		objHigh = new FlxUICheckBox(150, 270, null, null, 'High Quality', 110);
		objHigh.checked = true;
		objHigh.callback = function() {
			writeFiltersFromChecks();
			refreshFilterPreview();
			markDirty();
		};
		objStory = new FlxUICheckBox(15, 300, null, null, 'Story', 70);
		objStory.checked = true;
		objStory.callback = function() {
			writeFiltersFromChecks();
			refreshFilterPreview();
			markDirty();
		};
		objFreeplay = new FlxUICheckBox(100, 300, null, null, 'Freeplay', 90);
		objFreeplay.checked = true;
		objFreeplay.callback = function() {
			writeFiltersFromChecks();
			refreshFilterPreview();
			markDirty();
		};

		tab.add(objTypeTxt);
		tab.add(new FlxText(15, 24, 0, 'Name:'));
		tab.add(new FlxText(15, 64, 0, 'Image (images/, no extension):'));
		tab.add(new FlxText(15, 104, 0, 'X / Y'));
		tab.add(new FlxText(180, 104, 0, 'Scroll X / Y'));
		tab.add(new FlxText(15, 144, 0, 'Scale X / Y'));
		tab.add(new FlxText(180, 144, 0, 'Alpha / Angle'));
		tab.add(new FlxText(15, 184, 0, 'Dance every N beats / Color'));
		var objectWidgets:Array<Dynamic> = [
			objNameInput, objImageInput, reloadImg, objXStepper, objYStepper, objScaleXStepper, objScaleYStepper,
			objScrollXStepper, objScrollYStepper, objAlphaStepper, objAngleStepper, objDanceStepper, objColorInput,
			objFlipX, objFlipY, objAntialias, objLow, objHigh, objStory, objFreeplay
		];
		for (w in objectWidgets)
			tab.add(w);

		EditorTooltips.add(this, objDanceStepper, 'Replay the main animation every N beats. 0 leaves looping anims alone. 1 bops on every beat.');
		EditorTooltips.add(this, objImageInput, 'Path relative to images/, without .png. Animated sprites need a matching XML/txt atlas.');
		EditorTooltips.add(this, objStory, 'Show this prop in Story Mode. Uncheck (and leave Freeplay on) for a freeplay-only overlay.');
		EditorTooltips.add(this, objFreeplay, 'Show this prop in Freeplay. Uncheck (and leave Story on) for a story-only overlay.');

		UI_box.addGroup(tab);
	}

	function addAnimTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Anims';

		animNameInput = input(15, 30, 140, '');
		animSymbolInput = input(15, 70, 200, '');
		animIndicesInput = input(15, 110, 250, '');
		animFpsStepper = stepper(15, 150, 1, 24, 1, 60, 0);
		animLoopCheck = new FlxUICheckBox(110, 150, null, null, 'Loop', 60);
		animListTxt = new FlxText(15, 220, 300, '(no animations)');
		animListTxt.setFormat(null, 12, FlxColor.WHITE, LEFT);

		var addBtn = new FlxButton(15, 185, 'Add/Update', addOrUpdateAnim);
		var removeBtn = new FlxButton(110, 185, 'Remove', removeAnim);
		var mainBtn = new FlxButton(205, 185, 'Set Main', function() {
			var data = selectedData();
			if (data == null || data.type != 'animatedSprite') return;
			if (animNameInput.text.length < 1) return;
			data.firstAnimation = animNameInput.text;
			applySelectedVisual();
			markDirty();
			refreshAnimList();
		});

		tab.add(new FlxText(15, 12, 0, 'Animation name:'));
		tab.add(new FlxText(15, 54, 0, 'Atlas prefix / symbol:'));
		tab.add(new FlxText(15, 94, 0, 'Indices (optional, comma separated):'));
		var animWidgets:Array<Dynamic> = [
			animNameInput, animSymbolInput, animIndicesInput, animFpsStepper, animLoopCheck,
			addBtn, removeBtn, mainBtn, animListTxt
		];
		for (w in animWidgets)
			tab.add(w);

		UI_box.addGroup(tab);
	}

	function addSpriteList()
	{
		listBg = new FlxSprite(10, 20).makeGraphic(250, 280, 0xAA000000);
		listBg.cameras = [camHUD];
		listBg.scrollFactor.set();
		add(listBg);

		listTitle = new FlxText(14, 22, 240, 'Sprite List (front first)');
		listTitle.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT);
		listTitle.cameras = [camHUD];
		listTitle.scrollFactor.set();
		add(listTitle);

		listGroup = new FlxTypedGroup<FlxText>();
		add(listGroup);

		var up = new FlxButton(10, 305, 'Up', function() moveSelected(1));
		var down = new FlxButton(90, 305, 'Down', function() moveSelected(-1));
		var neu = new FlxButton(170, 305, 'New', function() createPopup.visible = createPopup.active = true);
		var dup = new FlxButton(10, 335, 'Dup', duplicateSelected);
		var del = new FlxButton(90, 335, 'Delete', deleteSelected);
		for (btn in [up, down, neu, dup, del])
		{
			btn.cameras = [camHUD];
			add(btn);
		}
		EditorTooltips.add(this, neu, 'Add a still sprite, an animated atlas sprite, or a solid rectangle.');
		EditorTooltips.add(this, del, 'Delete the selected prop. Character slots cannot be removed.');
	}

	function addCreatePopup()
	{
		createPopup = new FlxSpriteGroup();
		createPopup.cameras = [camHUD];
		var bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scale.set(280, 220);
		bg.updateHitbox();
		bg.screenCenter();
		createPopup.add(bg);
		var title = new FlxText(0, bg.y + 12, 280, 'New Sprite', 20);
		title.alignment = CENTER;
		title.screenCenter(X);
		createPopup.add(title);

		var still = new FlxButton(0, bg.y + 55, 'No Animation', function() spawnProp('sprite'));
		var anim = new FlxButton(0, bg.y + 95, 'Animated', function() spawnProp('animatedSprite'));
		var square = new FlxButton(0, bg.y + 135, 'Solid Color', function() spawnProp('square'));
		var cancel = new FlxButton(0, bg.y + 175, 'Cancel', function() createPopup.visible = createPopup.active = false);
		for (btn in [still, anim, square, cancel])
		{
			btn.screenCenter(X);
			createPopup.add(btn);
		}
		createPopup.visible = createPopup.active = false;
		add(createPopup);
	}

	inline function input(x:Float, y:Float, w:Int, text:String):CustomFlxUIInputText
	{
		var box = new CustomFlxUIInputText(x, y, w, text, 8);
		box.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		return box;
	}

	inline function stepper(x:Float, y:Float, step:Float, value:Float, min:Float, max:Float, decimals:Int):CustomFlxUINumericStepper
	{
		return new CustomFlxUINumericStepper(x, y, step, value, min, max, decimals);
	}

	/** Destroy JSON props and restack the world in `objects` order. */
	public function rebuildWorld()
	{
		for (meta in metas)
		{
			if (meta.sprite != gf && meta.sprite != dad && meta.sprite != boyfriend)
			{
				remove(meta.sprite);
				meta.sprite.destroy();
			}
		}
		metas = [];
		if (gf != null && members.indexOf(gf) >= 0) remove(gf);
		if (dad != null && members.indexOf(dad) >= 0) remove(dad);
		if (boyfriend != null && members.indexOf(boyfriend) >= 0) remove(boyfriend);

		StageEditorHelpers.repositionCharacters(this);

		var objects:Array<Dynamic> = cast stageJson.objects;
		for (obj in objects)
		{
			var type:String = StageEditorCore.canonicalType(obj.type);
			if (StageEditorCore.isCharacterType(type))
			{
				var char:Character = StageEditorHelpers.characterFor(this, type);
				add(char);
				metas.push({data: obj, sprite: char});
			}
			else
			{
				var spr:StagePropSprite = StageEditorHelpers.buildEditorSprite(obj);
				add(spr);
				metas.push({data: obj, sprite: spr});
			}
		}
		if (curSelected >= metas.length) curSelected = metas.length - 1;
		if (curSelected < 0) curSelected = 0;
		if (members.indexOf(selectionSprites) >= 0) remove(selectionSprites);
		add(selectionSprites);
		if (members.indexOf(cameraPointer) >= 0) remove(cameraPointer);
		add(cameraPointer);
		refreshFilterPreview();
		updateSelectionBox();
	}

	function updateSpriteList()
	{
		if (listGroup == null) return;
		while (listGroup.length > 0)
			listGroup.remove(listGroup.members[0], true);
		var labels = StageEditorCore.listLabels(stageJson.objects);
		var total:Int = labels.length;
		var front:Int = StageEditorCore.objectToListIndex(stageJson.objects, curSelected);
		var window:Int = StageEditorCore.LIST_WINDOW;
		listScroll = StageEditorCore.scrollToShow(total, front, listScroll, window);
		var end:Int = listScroll + window;
		if (end > total) end = total;
		var row:Int = 0;
		for (i in listScroll...end)
		{
			var txt = new FlxText(18, 44 + row * 16, 230, labels[i], 12);
			txt.setFormat(Paths.font('vcr.ttf'), 12, i == front ? FlxColor.LIME : FlxColor.WHITE);
			txt.cameras = [camHUD];
			txt.scrollFactor.set();
			listGroup.add(txt);
			row++;
		}
		if (listTitle != null)
		{
			listTitle.text = 'Sprite List (front first)';
			if (total > window)
				listTitle.text += '  ' + (listScroll + 1) + '-' + end + '/' + total;
		}
	}

	function selectedData():Dynamic
	{
		var objects:Array<Dynamic> = cast stageJson.objects;
		if (objects == null || curSelected < 0 || curSelected >= objects.length) return null;
		return objects[curSelected];
	}

	function selectedSprite():FlxSprite
	{
		if (curSelected < 0 || curSelected >= metas.length) return null;
		return metas[curSelected].sprite;
	}

	/** Copy the live UI / sprite transform back onto `stageJson`. */
	public function flushSelectedToJson()
	{
		stageJson.directory = directoryInput != null ? directoryInput.text : stageJson.directory;
		stageJson.defaultZoom = zoomStepper != null ? zoomStepper.value : stageJson.defaultZoom;
		stageJson.camera_speed = speedStepper != null ? speedStepper.value : stageJson.camera_speed;
		stageJson.shaders = StageEditorCore.shadersFromString(shadersInput != null ? shadersInput.text : '');
		if (nameInput != null && nameInput.text.length > 0) stageName = nameInput.text;
		if (stageJson._editorMeta == null) stageJson._editorMeta = {};
		if (gfNameInput != null) stageJson._editorMeta.gf = gfNameInput.text;
		if (dadNameInput != null) stageJson._editorMeta.dad = dadNameInput.text;
		if (bfNameInput != null) stageJson._editorMeta.boyfriend = bfNameInput.text;

		var data = selectedData();
		var spr = selectedSprite();
		if (data == null || spr == null) return;
		if (StageEditorCore.isCharacterType(data.type))
		{
			var type = StageEditorCore.canonicalType(data.type);
			var char:Character = cast spr;
			var pos = [spr.x - char.positionArray[0], spr.y - char.positionArray[1]];
			StageEditorCore.setCharacterPosition(stageJson, type, pos[0], pos[1]);
			return;
		}
		data.name = StageEditorCore.sanitizeName(stageJson.objects, objNameInput.text, curSelected);
		data.image = objImageInput.text;
		data.x = spr.x;
		data.y = spr.y;
		data.scale = [objScaleXStepper.value, objScaleYStepper.value];
		data.scroll = [objScrollXStepper.value, objScrollYStepper.value];
		data.alpha = objAlphaStepper.value;
		data.angle = objAngleStepper.value;
		data.danceEvery = objDanceStepper.value;
		data.color = objColorInput.text;
		data.flipX = objFlipX.checked;
		data.flipY = objFlipY.checked;
		data.antialiasing = objAntialias.checked;
		writeFiltersFromChecks();
	}

	function writeFiltersFromChecks()
	{
		var data = selectedData();
		if (data == null || StageEditorCore.isCharacterType(data.type)) return;
		if (objLow == null || objHigh == null || objStory == null || objFreeplay == null) return;
		data.filters = StageEditorCore.packFilters(objLow.checked, objHigh.checked, objStory.checked, objFreeplay.checked);
	}

	/** Refresh steppers, the sprite list and the selection rectangle. */
	public function updateSelectedUI()
	{
		ignoreUndo = true;
		var data = selectedData();
		updateSpriteList();
		if (data == null)
		{
			ignoreUndo = false;
			return;
		}
		var type = StageEditorCore.canonicalType(data.type);
		objTypeTxt.text = 'Type: ' + type + (StageEditorCore.isCharacterType(type) ? ' (character slot)' : '');

		var gfPos = StageEditorCore.characterPosition(stageJson, 'gf');
		var dadPos = StageEditorCore.characterPosition(stageJson, 'dad');
		var bfPos = StageEditorCore.characterPosition(stageJson, 'boyfriend');
		var gfCam = StageEditorCore.cameraOffset(stageJson, 'gf');
		var dadCam = StageEditorCore.cameraOffset(stageJson, 'dad');
		var bfCam = StageEditorCore.cameraOffset(stageJson, 'boyfriend');
		gfXStepper.value = gfPos[0];
		gfYStepper.value = gfPos[1];
		dadXStepper.value = dadPos[0];
		dadYStepper.value = dadPos[1];
		bfXStepper.value = bfPos[0];
		bfYStepper.value = bfPos[1];
		gfCamXStepper.value = gfCam[0];
		gfCamYStepper.value = gfCam[1];
		dadCamXStepper.value = dadCam[0];
		dadCamYStepper.value = dadCam[1];
		bfCamXStepper.value = bfCam[0];
		bfCamYStepper.value = bfCam[1];

		if (StageEditorCore.isCharacterType(type))
		{
			ignoreUndo = false;
			updateSelectionBox();
			return;
		}

		objNameInput.text = data.name != null ? Std.string(data.name) : '';
		objImageInput.text = data.image != null ? Std.string(data.image) : '';
		objXStepper.value = data.x;
		objYStepper.value = data.y;
		var scale = StageEditorCore.pair(data.scale);
		objScaleXStepper.value = scale[0];
		objScaleYStepper.value = scale[1];
		var scroll = StageEditorCore.pair(data.scroll);
		objScrollXStepper.value = scroll[0];
		objScrollYStepper.value = scroll[1];
		objAlphaStepper.value = data.alpha != null ? data.alpha : 1;
		objAngleStepper.value = data.angle != null ? data.angle : 0;
		objDanceStepper.value = data.danceEvery != null ? data.danceEvery : 0;
		objColorInput.text = StageEditorCore.colorToHex(StageEditorCore.parseColor(data.color));
		objFlipX.checked = data.flipX == true;
		objFlipY.checked = data.flipY == true;
		objAntialias.checked = data.antialiasing != false;
		var filters:Int = data.filters != null ? data.filters : StageEditorCore.FILTER_BOTH_QUALITY;
		objLow.checked = StageEditorCore.hasFilter(filters, StageEditorCore.FILTER_LOW);
		objHigh.checked = StageEditorCore.hasFilter(filters, StageEditorCore.FILTER_HIGH);
		if (objStory != null) objStory.checked = StageEditorCore.showsInStory(filters);
		if (objFreeplay != null) objFreeplay.checked = StageEditorCore.showsInFreeplay(filters);
		refreshAnimList();
		ignoreUndo = false;
		updateSelectionBox();
	}

	function applySelectedVisual()
	{
		var data = selectedData();
		var spr = selectedSprite();
		if (data == null || spr == null) return;
		if (Std.isOfType(spr, StagePropSprite))
			StageEditorHelpers.applyObjectToSprite(cast spr, data);
		updateSelectionBox();
	}

	function refreshFilterPreview()
	{
		if (showLowQuality == null || showHighQuality == null) return;
		var storyOn:Bool = showStoryMode == null || showStoryMode.checked;
		var freeOn:Bool = showFreeplayMode == null || showFreeplayMode.checked;
		for (meta in metas)
		{
			if (StageEditorCore.isCharacterType(meta.data.type)) continue;
			var show = StageEditorCore.previewVisible(meta.data.filters, showLowQuality.checked, showHighQuality.checked, storyOn, freeOn);
			meta.sprite.visible = show && meta.data.visible != false;
		}
	}

	function updateSelectionBox()
	{
		var spr = selectedSprite();
		if (spr == null)
		{
			selectionSprites.visible = false;
			return;
		}
		selectionSprites.visible = true;
		var x = spr.x;
		var y = spr.y;
		var w = spr.width;
		var h = spr.height;
		selectionSprites.members[0].setPosition(x, y);
		selectionSprites.members[0].setGraphicSize(Std.int(Math.max(1, w)), 2);
		selectionSprites.members[1].setPosition(x, y + h - 2);
		selectionSprites.members[1].setGraphicSize(Std.int(Math.max(1, w)), 2);
		selectionSprites.members[2].setPosition(x, y);
		selectionSprites.members[2].setGraphicSize(2, Std.int(Math.max(1, h)));
		selectionSprites.members[3].setPosition(x + w - 2, y);
		selectionSprites.members[3].setGraphicSize(2, Std.int(Math.max(1, h)));
		for (s in selectionSprites.members)
			s.updateHitbox();
	}

	function focusOn(target:String)
	{
		focusTarget = target;
		var char:Character = StageEditorHelpers.characterFor(this, target);
		var extra = StageEditorCore.cameraOffset(stageJson, target);
		if (char != null)
		{
			var mid = char.getMidpoint();
			camFollow.setPosition(mid.x + extra[0], mid.y + extra[1]);
			cameraPointer.setPosition(camFollow.x - cameraPointer.width / 2, camFollow.y - cameraPointer.height / 2);
		}
	}

	function spawnProp(type:String)
	{
		createPopup.visible = createPopup.active = false;
		flushSelectedToJson();
		var name = StageEditorCore.findUnoccupiedName(stageJson.objects, type == 'square' ? 'box' : 'sprite');
		var obj = StageEditorCore.defaultObject(type, name);
		obj.x = camFollow.x;
		obj.y = camFollow.y;
		var insertAt = curSelected + 1;
		StageEditorCore.insertObject(stageJson.objects, obj, insertAt);
		rebuildWorld();
		curSelected = insertAt < stageJson.objects.length ? insertAt : stageJson.objects.length - 1;
		updateSelectedUI();
		markDirty();
		showOutput('Added ' + name);
	}

	function duplicateSelected()
	{
		flushSelectedToJson();
		var before = stageJson.objects.length;
		StageEditorCore.duplicateObject(stageJson.objects, curSelected);
		if (stageJson.objects.length == before)
		{
			showOutput('Cannot duplicate a character slot.', true);
			return;
		}
		rebuildWorld();
		curSelected = curSelected + 1;
		updateSelectedUI();
		markDirty();
	}

	function deleteSelected()
	{
		flushSelectedToJson();
		var before = stageJson.objects.length;
		StageEditorCore.removeObject(stageJson.objects, curSelected);
		if (stageJson.objects.length == before)
		{
			showOutput('Cannot delete a character slot.', true);
			return;
		}
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function moveSelected(delta:Int)
	{
		flushSelectedToJson();
		curSelected = StageEditorCore.moveObject(stageJson.objects, curSelected, delta);
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function reloadSelectedImage()
	{
		var data = selectedData();
		if (data == null || StageEditorCore.isCharacterType(data.type)) return;
		data.image = objImageInput.text;
		flushSelectedToJson();
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function addOrUpdateAnim()
	{
		var data = selectedData();
		if (data == null || data.type != 'animatedSprite')
		{
			showOutput('Select an animated sprite first.', true);
			return;
		}
		if (animNameInput.text.length < 1)
		{
			showOutput('Animation name is empty.', true);
			return;
		}
		if (data.animations == null) data.animations = [];
		var indices:Array<Int> = [];
		if (animIndicesInput.text.length > 0)
		{
			for (part in animIndicesInput.text.split(','))
			{
				var n = Std.parseInt(StringTools.trim(part));
				if (n != null) indices.push(n);
			}
		}
		var existing:Int = -1;
		var anims:Array<Dynamic> = cast data.animations;
		for (i in 0...anims.length)
			if (anims[i].anim == animNameInput.text) existing = i;
		var entry:Dynamic = {
			anim: animNameInput.text,
			name: animSymbolInput.text,
			fps: Std.int(animFpsStepper.value),
			loop: animLoopCheck.checked,
			indices: indices
		};
		if (existing >= 0) anims[existing] = entry;
		else anims.push(entry);
		if (data.firstAnimation == null || data.firstAnimation.length < 1)
			data.firstAnimation = entry.anim;
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function removeAnim()
	{
		var data = selectedData();
		if (data == null || data.animations == null) return;
		var anims:Array<Dynamic> = cast data.animations;
		for (i in 0...anims.length)
		{
			if (anims[i].anim == animNameInput.text)
			{
				anims.splice(i, 1);
				break;
			}
		}
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function refreshAnimList()
	{
		var data = selectedData();
		if (data == null || data.animations == null || data.animations.length < 1)
		{
			animListTxt.text = '(no animations)';
			return;
		}
		var lines:Array<String> = [];
		var anims:Array<Dynamic> = cast data.animations;
		for (anim in anims)
		{
			var mark = (data.firstAnimation == anim.anim) ? ' *' : '';
			lines.push(anim.anim + '  [' + anim.name + ']' + mark);
		}
		animListTxt.text = lines.join('\n');
	}

	function replaceCharacter(slot:String, name:String)
	{
		if (name == null || name.length < 1) return;
		if (stageJson._editorMeta == null) stageJson._editorMeta = {};
		Reflect.setField(stageJson._editorMeta, slot, name);
		var old:Character = StageEditorHelpers.characterFor(this, slot);
		if (old != null)
		{
			if (members.indexOf(old) >= 0) remove(old);
			old.destroy();
		}
		var neu = makeCharacter(name, slot == 'boyfriend');
		switch (slot)
		{
			case 'gf': gf = neu;
			case 'dad': dad = neu;
			default: boyfriend = neu;
		}
	}

	function reloadCharacter(slot:String, name:String)
	{
		replaceCharacter(slot, name);
		rebuildWorld();
		updateSelectedUI();
		markDirty();
	}

	function loadBlank(week1:Bool)
	{
		stageJson = week1 ? StageEditorCore.week1Template() : StageEditorCore.dummyStage();
		StageEditorCore.ensureCharacterSlots(stageJson);
		stageName = week1 ? 'week1-template' : 'newStage';
		if (nameInput != null) nameInput.text = stageName;
		listScroll = 0;
		rebuildWorld();
		updateSelectedUI();
		undo.clear();
		pushUndo();
		unsavedProgress = true;
		showOutput(week1 ? 'Loaded Week 1 template.' : 'New blank stage.');
	}

	function loadStageNamed(name:String, force:Bool = false)
	{
		if (!force && name == stageName) return;
		var loaded = StageData.getStageFile(name);
		stageName = name;
		stageJson = loaded != null ? loaded : StageEditorCore.dummyStage();
		StageEditorCore.normalizeStage(stageJson);
		StageEditorCore.ensureCharacterSlots(stageJson);
		StageEditorHelpers.loadJsonDirectory(this);
		if (nameInput != null) nameInput.text = stageName;
		if (directoryInput != null) directoryInput.text = stageJson.directory;
		if (gfNameInput != null) gfNameInput.text = StageEditorHelpers.editorMetaName(stageJson, 'gf');
		if (dadNameInput != null) dadNameInput.text = StageEditorHelpers.editorMetaName(stageJson, 'dad');
		if (bfNameInput != null) bfNameInput.text = StageEditorHelpers.editorMetaName(stageJson, 'boyfriend');
		replaceCharacter('gf', StageEditorHelpers.editorMetaName(stageJson, 'gf'));
		replaceCharacter('dad', StageEditorHelpers.editorMetaName(stageJson, 'dad'));
		replaceCharacter('boyfriend', StageEditorHelpers.editorMetaName(stageJson, 'boyfriend'));
		listScroll = 0;
		rebuildWorld();
		updateSelectedUI();
		FlxG.camera.zoom = StageEditorCore.clampZoom(stageJson.defaultZoom);
		undo.clear();
		pushUndo();
		unsavedProgress = false;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Stage Editor', 'Stage: ' + stageName);
		#end
		showOutput('Loaded ' + name);
	}

	/** Replace the working copy with parsed JSON from a file picker. */
	public function applyLoadedJson(raw:String, name:String)
	{
		stageJson = StageEditorCore.parse(raw);
		StageEditorCore.ensureCharacterSlots(stageJson);
		if (name != null && StringTools.endsWith(name.toLowerCase(), '.json'))
			name = name.substr(0, name.length - 5);
		stageName = name;
		if (nameInput != null) nameInput.text = stageName;
		StageEditorHelpers.loadJsonDirectory(this);
		replaceCharacter('gf', StageEditorHelpers.editorMetaName(stageJson, 'gf'));
		replaceCharacter('dad', StageEditorHelpers.editorMetaName(stageJson, 'dad'));
		replaceCharacter('boyfriend', StageEditorHelpers.editorMetaName(stageJson, 'boyfriend'));
		listScroll = 0;
		rebuildWorld();
		updateSelectedUI();
		undo.clear();
		pushUndo();
		unsavedProgress = false;
		showOutput('Loaded ' + name);
	}

	function saveToMod()
	{
		flushSelectedToJson();
		stageName = StageEditorCore.sanitizeStageFileName(nameInput != null && nameInput.text.length > 0 ? nameInput.text : stageName);
		if (nameInput != null) nameInput.text = stageName;
		var data = StageEditorHelpers.stageJsonText(this);
		var path = StageEditorHelpers.currentModStagePath(stageName);
		#if sys
		if (StageEditorHelpers.writeStageFile(path, data))
		{
			unsavedProgress = false;
			showOutput('Saved ' + path);
		}
		else
			showOutput('Could not write ' + path, true);
		#else
		showOutput('Save to Mod needs a desktop/Android build. Use Save to export.', true);
		#end
	}

	function copyJson()
	{
		flushSelectedToJson();
		var data = StageEditorHelpers.stageJsonText(this);
		Clipboard.text = data;
		showOutput('Copied ' + stageName + '.json');
	}

	function saveStage()
	{
		flushSelectedToJson();
		var data = StageEditorHelpers.stageJsonText(this);
		var fileName = StageEditorCore.sanitizeStageFileName(stageName) + '.json';
		#if android
		MobileFilePicker.saveText(data, fileName, 'application/json', 'Save stage as', function(result) {
			if (result != null)
			{
				unsavedProgress = false;
				showOutput('Saved ' + fileName);
			}
		});
		#else
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(data, fileName);
		#end
	}

	function loadStageFile()
	{
		#if android
		MobileFilePicker.openFile(function(picked) {
			if (picked == null || picked.data == null) return;
			applyLoadedJson(picked.data.toString(), picked.name != null && picked.name.length > 0 ? picked.name : 'imported');
		}, ['json'], 'Open stage JSON');
		#else
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadSelect);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.browse([new FileFilter('JSON', '*.json')]);
		#end
	}

	function onLoadSelect(_):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.addEventListener(Event.COMPLETE, onLoadComplete);
		_file.load();
	}

	function onLoadComplete(_):Void
	{
		var raw = _file.data.toString();
		var name = _file.name != null ? _file.name : 'imported';
		if (StringTools.endsWith(name.toLowerCase(), '.json'))
			name = name.substr(0, name.length - 5);
		clearFile();
		applyLoadedJson(raw, name);
	}

	function onSaveComplete(_):Void
	{
		clearFile();
		unsavedProgress = false;
		showOutput('Saved ' + stageName + '.json');
	}

	function onSaveCancel(_):Void
	{
		clearFile();
	}

	function onSaveError(_):Void
	{
		clearFile();
		showOutput('Problem saving file.', true);
	}

	function clearFile()
	{
		if (_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.COMPLETE, onLoadComplete);
		_file = null;
	}

	function markDirty()
	{
		unsavedProgress = true;
		if (!ignoreUndo) pushUndo();
	}

	function pushUndo()
	{
		undo.push(StageEditorCore.stringify(stageJson));
	}

	function applyUndo(raw:Null<String>)
	{
		if (raw == null) return;
		ignoreUndo = true;
		stageJson = StageEditorCore.parse(raw);
		StageEditorCore.ensureCharacterSlots(stageJson);
		rebuildWorld();
		updateSelectedUI();
		ignoreUndo = false;
		unsavedProgress = true;
	}

	/** Flash a HUD status line. Errors play `cancelMenu`. */
	public function showOutput(text:String, isError:Bool = false)
	{
		outputTxt.text = text;
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.alpha = 1;
		outputTime = 2.5;
		if (isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function typing():Bool
	{
		var boxes:Array<CustomFlxUIInputText> = [
			nameInput, directoryInput, shadersInput, gfNameInput, dadNameInput, bfNameInput,
			objNameInput, objImageInput, objColorInput, animNameInput, animSymbolInput, animIndicesInput
		];
		for (box in boxes)
			if (box != null && box.hasFocus) return true;
		return false;
	}

	function mouseOnUI():Bool
	{
		var p = FlxG.mouse.getScreenPosition(camHUD);
		if (createPopup != null && createPopup.visible) return true;
		if (p.x < 270 && p.y < 370) return true;
		if (p.x > FlxG.width - 360 && p.y < 430) return true;
		if (p.y > FlxG.height - 70) return true;
		return false;
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (ignoreUndo) return;
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is CustomFlxUIInputText))
		{
			if (sender == nameInput && nameInput.text.length > 0) stageName = nameInput.text;
			else if (sender == directoryInput) stageJson.directory = directoryInput.text;
			else if (sender == shadersInput) stageJson.shaders = StageEditorCore.shadersFromString(shadersInput.text);
			else if (sender == objNameInput || sender == objImageInput || sender == objColorInput)
			{
				flushSelectedToJson();
				if (sender == objColorInput) applySelectedVisual();
				unsavedProgress = true;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is CustomFlxUINumericStepper))
		{
			if (sender == zoomStepper)
			{
				stageJson.defaultZoom = zoomStepper.value;
				FlxG.camera.zoom = StageEditorCore.clampZoom(zoomStepper.value);
				markDirty();
			}
			else if (sender == speedStepper)
			{
				stageJson.camera_speed = speedStepper.value;
				markDirty();
			}
			else if (sender == gfXStepper || sender == gfYStepper)
			{
				StageEditorCore.setCharacterPosition(stageJson, 'gf', gfXStepper.value, gfYStepper.value);
				StageEditorHelpers.repositionCharacters(this);
				markDirty();
			}
			else if (sender == dadXStepper || sender == dadYStepper)
			{
				StageEditorCore.setCharacterPosition(stageJson, 'dad', dadXStepper.value, dadYStepper.value);
				StageEditorHelpers.repositionCharacters(this);
				markDirty();
			}
			else if (sender == bfXStepper || sender == bfYStepper)
			{
				StageEditorCore.setCharacterPosition(stageJson, 'boyfriend', bfXStepper.value, bfYStepper.value);
				StageEditorHelpers.repositionCharacters(this);
				markDirty();
			}
			else if (sender == gfCamXStepper || sender == gfCamYStepper)
			{
				StageEditorCore.setCameraOffset(stageJson, 'gf', gfCamXStepper.value, gfCamYStepper.value);
				focusOn('gf');
				markDirty();
			}
			else if (sender == dadCamXStepper || sender == dadCamYStepper)
			{
				StageEditorCore.setCameraOffset(stageJson, 'dad', dadCamXStepper.value, dadCamYStepper.value);
				focusOn('dad');
				markDirty();
			}
			else if (sender == bfCamXStepper || sender == bfCamYStepper)
			{
				StageEditorCore.setCameraOffset(stageJson, 'boyfriend', bfCamXStepper.value, bfCamYStepper.value);
				focusOn('boyfriend');
				markDirty();
			}
			else
			{
				var obj = selectedData();
				var spr = selectedSprite();
				if (obj != null && spr != null && !StageEditorCore.isCharacterType(obj.type))
				{
					if (sender == objXStepper) spr.x = obj.x = objXStepper.value;
					else if (sender == objYStepper) spr.y = obj.y = objYStepper.value;
					else
					{
						flushSelectedToJson();
						applySelectedVisual();
					}
					updateSelectionBox();
					markDirty();
				}
			}
		}
	}

	override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed) FlxG.sound.play(Paths.sound('click'));
		MusicBeatState.camBeat = FlxG.camera;

		if (outputTime > 0)
		{
			outputTime -= elapsed;
			if (outputTime <= 0) outputTxt.alpha = 0;
		}

		if (typing())
		{
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
			super.update(elapsed);
			return;
		}
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;

		if (helpBg.visible && FlxG.keys.justPressed.ESCAPE)
		{
			helpBg.visible = helpTexts.visible = false;
			super.update(elapsed);
			return;
		}

		if (createPopup.visible && (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE))
		{
			createPopup.visible = createPopup.active = false;
			super.update(elapsed);
			return;
		}

		if (FlxG.keys.justPressed.F1)
			helpBg.visible = helpTexts.visible = !helpBg.visible;

		if (FlxG.keys.justPressed.F12)
			selectionSprites.visible = !selectionSprites.visible;

		if (FlxG.keys.justPressed.ESCAPE)
		{
			tryExit();
			super.update(elapsed);
			return;
		}

		var ctrl = FlxG.keys.pressed.CONTROL;
		if (ctrl && FlxG.keys.justPressed.S && FlxG.keys.pressed.SHIFT) saveToMod();
		else if (ctrl && FlxG.keys.justPressed.S) saveStage();
		if (ctrl && FlxG.keys.justPressed.Y) applyUndo(undo.redo());
		else if (ctrl && FlxG.keys.justPressed.Z && FlxG.keys.pressed.SHIFT) applyUndo(undo.redo());
		else if (ctrl && FlxG.keys.justPressed.Z) applyUndo(undo.undo());

		if (FlxG.keys.justPressed.G)
		{
			snapToGrid = !snapToGrid;
			if (gridCheck != null) gridCheck.checked = snapToGrid;
			showOutput(snapToGrid ? ('Snap to ' + StageEditorCore.GRID_SIZE + 'px grid') : 'Grid off');
		}

		if (FlxG.keys.justPressed.Q)
			FlxG.camera.zoom = StageEditorCore.clampZoom(FlxG.camera.zoom - (FlxG.keys.pressed.SHIFT ? 0.1 : 0.05));
		if (FlxG.keys.justPressed.E)
			FlxG.camera.zoom = StageEditorCore.clampZoom(FlxG.camera.zoom + (FlxG.keys.pressed.SHIFT ? 0.1 : 0.05));
		if (FlxG.keys.justPressed.R)
			FlxG.camera.zoom = StageEditorCore.clampZoom(stageJson.defaultZoom);

		var pan:Float = (FlxG.keys.pressed.SHIFT ? 8 : 4) * (ctrl ? 0.25 : 1);
		if (FlxG.keys.pressed.J) camFollow.x -= pan;
		if (FlxG.keys.pressed.L) camFollow.x += pan;
		if (FlxG.keys.pressed.I) camFollow.y -= pan;
		if (FlxG.keys.pressed.K) camFollow.y += pan;

		if (FlxG.mouse.pressedRight)
		{
			camFollow.x -= FlxG.mouse.deltaScreenX / FlxG.camera.zoom;
			camFollow.y -= FlxG.mouse.deltaScreenY / FlxG.camera.zoom;
		}

		if (listBg != null && FlxG.mouse.overlaps(listBg, camHUD) && FlxG.mouse.wheel != 0)
		{
			var total:Int = stageJson.objects != null ? stageJson.objects.length : 0;
			listScroll = StageEditorCore.clampListScroll(total, listScroll - Std.int(FlxG.mouse.wheel), StageEditorCore.LIST_WINDOW);
			updateSpriteList();
		}
		else if (!mouseOnUI() && FlxG.mouse.wheel != 0)
			FlxG.camera.zoom = StageEditorCore.clampZoom(FlxG.camera.zoom + FlxG.mouse.wheel * 0.05);

		if (FlxG.mouse.justPressed && !mouseOnUI())
			pickAtMouse();

		if (FlxG.mouse.justPressed && listBg != null && FlxG.mouse.overlaps(listBg, camHUD))
			pickFromList();

		var spr = selectedSprite();
		var data = selectedData();
		if (spr != null && data != null)
		{
			if (FlxG.mouse.pressed && dragging && !mouseOnUI())
			{
				spr.x += FlxG.mouse.deltaScreenX / FlxG.camera.zoom;
				spr.y += FlxG.mouse.deltaScreenY / FlxG.camera.zoom;
				var dragGrid:Float = ctrl ? 1 : (snapToGrid ? StageEditorCore.GRID_SIZE : 0);
				if (dragGrid > 0)
				{
					spr.x = StageEditorCore.snap(spr.x, dragGrid);
					spr.y = StageEditorCore.snap(spr.y, dragGrid);
				}
				StageEditorHelpers.syncSpriteToData(spr, data);
				if (StageEditorCore.isCharacterType(data.type))
				{
					var char:Character = cast spr;
					StageEditorCore.setCharacterPosition(stageJson, data.type, spr.x - char.positionArray[0], spr.y - char.positionArray[1]);
				}
				updateSelectionBox();
			}
			if (FlxG.mouse.justPressed && !mouseOnUI() && FlxG.mouse.overlaps(spr, camEditor))
				dragging = true;
			if (FlxG.mouse.justReleased && dragging)
			{
				dragging = false;
				markDirty();
				updateSelectedUI();
			}

			var grid = ctrl ? 1 : (snapToGrid ? StageEditorCore.GRID_SIZE : 0);
			var fast = FlxG.keys.pressed.SHIFT;
			var moved = false;
			if (FlxG.keys.justPressed.LEFT)
			{
				spr.x = StageEditorCore.nudge(spr.x, -1, fast, grid);
				moved = true;
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				spr.x = StageEditorCore.nudge(spr.x, 1, fast, grid);
				moved = true;
			}
			if (FlxG.keys.justPressed.UP)
			{
				spr.y = StageEditorCore.nudge(spr.y, -1, fast, grid);
				moved = true;
			}
			if (FlxG.keys.justPressed.DOWN)
			{
				spr.y = StageEditorCore.nudge(spr.y, 1, fast, grid);
				moved = true;
			}
			if (moved)
			{
				StageEditorHelpers.syncSpriteToData(spr, data);
				if (StageEditorCore.isCharacterType(data.type))
				{
					var char:Character = cast spr;
					StageEditorCore.setCharacterPosition(stageJson, data.type, spr.x - char.positionArray[0], spr.y - char.positionArray[1]);
				}
				updateSelectionBox();
				markDirty();
			}
		}

		var extra = StageEditorCore.cameraOffset(stageJson, focusTarget);
		var focusChar = StageEditorHelpers.characterFor(this, focusTarget);
		if (focusChar != null)
			cameraPointer.setPosition(focusChar.getMidpoint().x + extra[0] - cameraPointer.width / 2,
				focusChar.getMidpoint().y + extra[1] - cameraPointer.height / 2);

		var sel = selectedData();
		if (sel != null)
			posTxt.text = StageEditorCore.labelFor(sel) + '   X: ' + Std.int(selectedSprite() != null ? selectedSprite().x : 0)
				+ ' Y: ' + Std.int(selectedSprite() != null ? selectedSprite().y : 0)
				+ '   zoom ' + (Math.round(FlxG.camera.zoom * 100) / 100)
				+ (snapToGrid ? '   grid ' + StageEditorCore.GRID_SIZE : '');
		else
			posTxt.text = '';

		super.update(elapsed);
		if (music != null) music.update(elapsed);
	}

	function pickAtMouse()
	{
		var i = metas.length - 1;
		while (i >= 0)
		{
			var spr = metas[i].sprite;
			if (spr != null && spr.visible && FlxG.mouse.overlaps(spr, camEditor))
			{
				curSelected = i;
				dragging = true;
				updateSelectedUI();
				return;
			}
			i--;
		}
	}

	function pickFromList()
	{
		var p = FlxG.mouse.getScreenPosition(camHUD);
		if (p.y < 44) return;
		var idx = listScroll + Std.int((p.y - 44) / 16);
		var objects:Array<Dynamic> = cast stageJson.objects;
		var objIndex = StageEditorCore.listIndexToObject(objects, idx);
		if (objIndex >= 0)
		{
			curSelected = objIndex;
			updateSelectedUI();
		}
	}

	function tryExit()
	{
		if (!unsavedProgress)
		{
			reallyExit();
			return;
		}
		openSubState(new Prompt('You have unsaved changes.\nExit anyway?', 0, reallyExit, function() {}, false, 'Exit', 'Cancel'));
	}

	function reallyExit()
	{
		FlxG.mouse.visible = false;
		if (music != null && music.music != null) music.destroy();
		if (goToPlayState) FlxG.switchState(() -> new play.PlayState());
		else
		{
			FlxG.switchState(MasterEditorMenu.new);
			Paths.playMenuMusic(true);
		}
	}

	override public function onFocusLost():Void
	{
		if (music != null) music.pauseMusic();
		super.onFocusLost();
	}

	override public function onFocus():Void
	{
		if (music != null) music.unpauseMusic();
		super.onFocus();
	}
}
