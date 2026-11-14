package editors;

using StringTools;

import backend.ClientPrefs;
import backend.MusicBeatState;
import backend.Paths;

import flixel.text.FlxText.FlxTextAlign;

import modchart.ModchartEase;
import modchart.ModchartManager;
import modchart.ModchartOutput;
import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.PlayField;
import modchart.lab.LabKnob;
import modchart.lab.LabLanguage;
import modchart.lab.LabModifier;
import modchart.lab.ModchartLabCatalog;
import modchart.lab.ModchartLabExport;
import modchart.lab.ModchartLabExportOptions;
import modchart.lab.ModchartLabTrack;
import objects.StrumNote;

/** One arrow of the preview: a receptor, or one of the ghost notes falling onto it. */
typedef LabArrow =
{
	var sprite:StrumNote;
	var lane:Int;
	var player:Int;
	/** Ghost index inside its lane (`0` for receptors). */
	var ghost:Int;
	var receptor:Bool;
}

/** One slider slot of the right-hand panel, bound to a knob while it is visible. */
typedef LabKnobRow =
{
	var knob:Null<LabKnob>;
	var label:FlxText;
	var value:FlxText;
	var bar:FlxSprite;
	var fill:FlxSprite;
	var handle:FlxSprite;
}

/** A flat, mouse-clickable button with a label. */
typedef LabButton =
{
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var bg:FlxSprite;
	var label:FlxText;
	var action:Void->Void;
}

/**
 * Modchart Lab — the visual counterpart to the modchart runtime.
 *
 * Pick one of the 34 modifiers, drag its percents while a beat clock loops
 * over a section, watch the preview arrows react, then copy the equivalent
 * `addModifier`/`modSet`/`modEase` calls as Lua or Python. The preview runs
 * the real `ModchartManager` with synthetic `ModchartParams` (no
 * `PlayState`), so what is shown is what the runtime does.
 *
 * Recording model: every drag is captured as a keyframe of the current
 * (modifier, percent, side) track, snapped to the 16th-note grid and stored
 * in **loop-local** beats. The section start only shifts the exported beats,
 * so moving it does not invalidate the shape. Boxed keyframes are replayed
 * every pass, which is why a section can be tuned over several loops.
 *
 * See `docs/MODCHART.md` (Modchart lab) for the walkthrough.
 */
class ModchartLabState extends MusicBeatState
{
	// ----------------------------------------------------------------
	// Layout / tuning
	// ----------------------------------------------------------------

	static inline final LANE_COUNT:Int = 4;
	static inline final LANE_SPACING:Float = 82;
	/** Note skins are ~112px wide; the preview shrinks them so two fields fit. */
	static inline final ARROW_SCALE:Float = 0.55;
	static inline final GHOSTS_PER_LANE:Int = 2;
	static inline final LIST_COLUMNS:Int = 2;
	static inline final LIST_ROWS:Int = 17;
	static inline final LIST_COLUMN_WIDTH:Float = 138;
	static inline final LIST_ROW_HEIGHT:Float = 22;
	static inline final KNOB_SLOTS:Int = 10;
	static inline final KNOB_ROW_HEIGHT:Float = 42;
	static inline final KNOB_TOP:Float = 96;
	static inline final KEY_GRID:Float = 0.25;
	static inline final BOTTOM_BAR:Float = 150;
	static inline final CODE_LINES:Int = 6;
	static inline final MIN_LENGTH:Float = 1;
	static inline final MAX_LENGTH:Float = 32;
	static inline final SAVED_COPY_FILE:String = 'modchart-lab.txt';
	static inline final MIN_BPM:Float = 30;
	static inline final MAX_BPM:Float = 300;

	// ----------------------------------------------------------------
	// Model
	// ----------------------------------------------------------------

	var catalog:Array<LabModifier> = [];
	var manager:ModchartManager;
	var field:PlayField;
	var tracks:Array<ModchartLabTrack> = [];
	var options:ModchartLabExportOptions = new ModchartLabExportOptions();

	var selected:Int = 0;
	var selectedKnob:Int = 0;
	var knobScroll:Int = 0;
	var side:Int = -1;
	var playing:Bool = true;
	var bpm:Float = 120;
	var phase:Float = 0;
	var easeName:String = 'quadOut';
	var easeFn:Float->Float = ModchartEase.quadOut;

	var params:ModchartParams = new ModchartParams();
	var output:ModchartOutput = new ModchartOutput();
	var basePos:ModchartVec3 = new ModchartVec3();

	var previewArrows:Array<LabArrow> = [];
	var maxGhostDistance:Float = 240;

	var dragging:Null<LabKnobRow> = null;
	var scrubbing:Bool = false;
	var exportDirty:Bool = true;
	var rulerDirty:Bool = true;
	var listDirty:Bool = true;
	var exiting:Bool = false;
	var labelTimer:Float = 0;
	var copiedTimer:Float = 0;
	var copyNote:String = 'COPIED';

	// ----------------------------------------------------------------
	// Layout
	// ----------------------------------------------------------------

	var listX:Float = 12;
	var listY:Float = 92;
	var previewX:Float = 300;
	var previewY:Float = 52;
	var previewW:Float = 680;
	var previewH:Float = 456;
	var rightX:Float = 992;
	var rightW:Float = 276;
	var rulerX:Float = 300;
	var rulerY:Float = 530;
	var rulerW:Float = 680;
	var rulerH:Float = 14;
	var barY:Float = 570;

	// ----------------------------------------------------------------
	// Sprites
	// ----------------------------------------------------------------

	var listRows:Array<FlxText> = [];
	var listHighlight:FlxSprite;
	var modifierHint:FlxText;
	var knobHeader:FlxText;
	var sideHint:FlxText;
	var knobRows:Array<LabKnobRow> = [];
	var beatTicks:Array<FlxSprite> = [];
	var keyTicks:Array<FlxSprite> = [];
	var playhead:FlxSprite;
	var rulerLabel:FlxText;
	var statusText:FlxText;
	var codeText:FlxText;
	var buttons:Array<LabButton> = [];
	var playButton:LabButton;
	var langButton:LabButton;
	var loopButton:LabButton;
	var easeLabel:FlxText;
	var bpmLabel:FlxText;

	// ----------------------------------------------------------------
	// Lifecycle
	// ----------------------------------------------------------------

	override function create():Void
	{
		catalog = ModchartLabCatalog.all();
		FlxG.camera.bgColor = 0xFF0D0D13;
		FlxG.mouse.visible = true;

		computeLayout();
		addBackdrop();
		addHeaders();
		addPreview();
		addRuler();
		addModifierList();
		addKnobPanel();
		addBottomBar();

		ensureModifier();
		refreshSelection();

		super.create();
	}

	override function destroy():Void
	{
		FlxG.mouse.visible = false;
		super.destroy();
	}

	override function update(elapsed:Float):Void
	{
		// Automation first: input (a drag, a nudge) then wins for this frame,
		// and next frame replays the keyframe that input just recorded.
		updateClock(elapsed);
		applyAutomation();

		handleKeyboard();
		if (exiting)
			return;
		handleMouse();
		transformArrows();
		refreshExportIfNeeded();

		labelTimer -= elapsed;
		if (copiedTimer > 0)
			copiedTimer -= elapsed;
		if (labelTimer <= 0)
		{
			labelTimer = 0.08;
			refreshKnobValues();
			refreshStatus();
			refreshRulerLabel();
			if (rulerDirty)
			{
				rulerDirty = false;
				refreshRuler();
			}
			if (listDirty)
			{
				listDirty = false;
				refreshListLabels();
			}
		}
		super.update(elapsed);
	}

	// ----------------------------------------------------------------
	// Construction
	// ----------------------------------------------------------------

	function computeLayout():Void
	{
		previewX = 300;
		previewW = Math.max(340, FlxG.width - previewX - 300);
		previewY = 52;
		barY = FlxG.height - BOTTOM_BAR;
		rulerX = previewX;
		rulerW = previewW;
		rulerY = barY - 40;
		previewH = Math.max(180, rulerY - previewY - 22);
		rightX = FlxG.width - 288;
		rightW = 276;
		listX = 12;
		listY = 92;
	}

	function addBackdrop():Void
	{
		final bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF101018);
		bg.scrollFactor.set();
		add(bg);
	}

	function addHeaders():Void
	{
		makeText(12, 8, 640, 'MODCHART LAB', 20, FlxColor.WHITE);
		makeText(12, 32, FlxG.width - 640, 'Drag a percent over a looping section, then copy the modEase(...) calls as Lua or Python.', 11, 0xFF8C8CA8);
	}

	function addPreview():Void
	{
		final panel:FlxSprite = new FlxSprite(previewX - 6, previewY - 6).makeGraphic(Std.int(previewW + 12), Std.int(previewH + 12), 0xFF16161F);
		add(panel);

		manager = new ModchartManager();
		field = manager.playfields[0];
		field.keyCount = LANE_COUNT;
		field.screenWidth = FlxG.width;
		field.screenHeight = FlxG.height;
		field.crochet = 60000 / bpm;
		field.downscroll = ClientPrefs.downScroll;
		field.usePerspective = true;
		layoutField();

		for (player in 0...2)
		{
			for (lane in 0...LANE_COUNT)
			{
				previewArrows.push({sprite: makeArrow(lane, player, false), lane: lane, player: player, ghost: 0, receptor: true});
				for (ghost in 0...GHOSTS_PER_LANE)
					previewArrows.push({sprite: makeArrow(lane, player, true), lane: lane, player: player, ghost: ghost, receptor: false});
			}
		}
	}

	/** Places the receptors inside the preview box and sizes the ghost travel. */
	function layoutField():Void
	{
		final centerX:Float = previewX + previewW * 0.5;
		final sideOffset:Float = Math.min(previewW * 0.23, 220);
		final receptorLine:Float = previewY + previewH * (field.downscroll ? 0.62 : 0.38);

		field.receptorX = [[], []];
		field.receptorY = [[], []];
		for (player in 0...2)
		{
			final sideCenter:Float = centerX + (player == 0 ? -sideOffset : sideOffset);
			for (lane in 0...LANE_COUNT)
			{
				field.receptorX[player][lane] = sideCenter + (lane - (LANE_COUNT - 1) * 0.5) * LANE_SPACING;
				field.receptorY[player][lane] = receptorLine;
			}
		}
		final travel:Float = field.downscroll ? receptorLine - previewY : previewY + previewH - receptorLine;
		// Leave room for the shrunk sprite so a ghost never pokes out of the box.
		maxGhostDistance = Math.max(120, travel * 0.7);
	}

	function makeArrow(lane:Int, player:Int, ghost:Bool):StrumNote
	{
		final arrow:StrumNote = new StrumNote(0, 0, lane, player, true);
		arrow.playAnim('static');
		arrow.alpha = ghost ? 0.5 : 1;
		add(arrow);
		return arrow;
	}

	function addRuler():Void
	{
		final bg:FlxSprite = new FlxSprite(rulerX, rulerY).makeGraphic(Std.int(rulerW), Std.int(rulerH), 0xFF1C1C2A);
		add(bg);

		for (_ in 0...128)
		{
			final tick:FlxSprite = new FlxSprite().makeGraphic(1, Std.int(rulerH - 4), 0xFF3C3C58);
			tick.exists = false;
			tick.visible = false;
			add(tick);
			beatTicks.push(tick);
		}
		for (_ in 0...96)
		{
			final tick:FlxSprite = new FlxSprite().makeGraphic(2, Std.int(rulerH), 0xFF7DD3FC);
			tick.exists = false;
			tick.visible = false;
			add(tick);
			keyTicks.push(tick);
		}
		playhead = new FlxSprite().makeGraphic(2, Std.int(rulerH + 8), 0xFFFFE066);
		playhead.x = rulerX;
		playhead.y = rulerY - 4;
		add(playhead);

		rulerLabel = makeText(rulerX, rulerY - 14, rulerW, '', 10, 0xFF9A9AB4);
		rebuildBeatTicks();
	}

	function addModifierList():Void
	{
		final panelH:Float = Math.max(180, barY - previewY - 6);
		final panel:FlxSprite = new FlxSprite(listX - 4, previewY - 6).makeGraphic(Std.int(LIST_COLUMN_WIDTH * LIST_COLUMNS + 8), Std.int(panelH), 0xFF16161F);
		add(panel);

		listHighlight = new FlxSprite().makeGraphic(Std.int(LIST_COLUMN_WIDTH) - 2, Std.int(LIST_ROW_HEIGHT) - 3, 0xFF34344E);
		listHighlight.alpha = 0.95;
		add(listHighlight);

		for (i in 0...catalog.length)
		{
			final col:Int = Std.int(i / LIST_ROWS);
			final row:Int = i % LIST_ROWS;
			final label:FlxText = makeText(listX + col * LIST_COLUMN_WIDTH, listY + row * LIST_ROW_HEIGHT, LIST_COLUMN_WIDTH - 6, catalog[i].label, 11,
				0xFFB4B4C8);
			listRows.push(label);
		}

		final hintY:Float = listY + LIST_ROWS * LIST_ROW_HEIGHT + 6;
		modifierHint = makeText(listX, hintY, LIST_COLUMN_WIDTH * LIST_COLUMNS - 8, '', 11, 0xFFD8D8E8);
		modifierHint.wordWrap = true;
	}

	function addKnobPanel():Void
	{
		final panelH:Float = Math.max(180, barY - previewY - 6);
		final panel:FlxSprite = new FlxSprite(rightX - 6, previewY - 6).makeGraphic(Std.int(rightW + 12), Std.int(panelH), 0xFF16161F);
		add(panel);

		knobHeader = makeText(rightX, 60, rightW, 'PERCENTS', 12, 0xFFB4B4C8);
		sideHint = makeText(rightX, 78, rightW, '', 10, 0xFF8C8CA8);

		for (slot in 0...KNOB_SLOTS)
		{
			final y:Float = KNOB_TOP + slot * KNOB_ROW_HEIGHT;
			final bar:FlxSprite = new FlxSprite(rightX, y + 18).makeGraphic(Std.int(rightW), 8, 0xFF24242F);
			final fill:FlxSprite = new FlxSprite(rightX, y + 18).makeGraphic(1, 8, 0xFF4C4C7A);
			final handle:FlxSprite = new FlxSprite(rightX, y + 15).makeGraphic(6, 14, 0xFFFFE066);
			add(bar);
			add(fill);
			add(handle);

			final label:FlxText = makeText(rightX, y, rightW - 66, '', 11, FlxColor.WHITE);
			final value:FlxText = makeText(rightX + rightW - 62, y, 62, '', 11, 0xFF7DD3FC, RIGHT);
			knobRows.push({knob: null, label: label, value: value, bar: bar, fill: fill, handle: handle});
		}
	}

	function addBottomBar():Void
	{
		final bg:FlxSprite = new FlxSprite(0, barY).makeGraphic(FlxG.width, Std.int(FlxG.height - barY), 0xFF14141E);
		add(bg);

		var x:Float = 12;
		final y:Float = barY + 8;
		playButton = addButton(x, y, 106, 22, 'Pause [SPACE]', togglePlay);
		x += 112;
		addButton(x, y, 46, 22, 'BPM -', function() setBpm(bpm - 5));
		x += 50;
		addButton(x, y, 46, 22, 'BPM +', function() setBpm(bpm + 5));
		x += 54;
		addButton(x, y, 58, 22, 'Start -', function() setStart(-1));
		x += 62;
		addButton(x, y, 58, 22, 'Start +', function() setStart(1));
		x += 62;
		addButton(x, y, 50, 22, 'Len -', function() setLength(-1));
		x += 54;
		addButton(x, y, 50, 22, 'Len +', function() setLength(1));
		x += 62;
		addButton(x, y, 28, 22, '<', function() cycleEase(-1));
		x += 32;
		addButton(x, y, 28, 22, '>', function() cycleEase(1));
		x += 36;
		langButton = addButton(x, y, 84, 22, 'Lua [TAB]', toggleLanguage);
		x += 88;
		loopButton = addButton(x, y, 92, 22, 'Loop: off', toggleLoop);
		x += 96;
		addButton(x, y, 78, 22, 'Copy [C]', copyCode);
		x += 82;
		addButton(x, y, 82, 22, 'Clear [X]', clearCurrentTrack);

		bpmLabel = makeText(rightX, barY + 8, 120, '', 11, 0xFF9A9AB4, RIGHT);
		easeLabel = makeText(rightX, barY + 30, 120, '', 11, 0xFF7DD3FC, RIGHT);

		statusText = makeText(12, barY + 34, FlxG.width - 320, '', 11, 0xFF9A9AB4);
		statusText.wordWrap = true;
		codeText = makeText(12, barY + 58, FlxG.width - 24, '', 11, 0xFFCBD5E1);
		codeText.wordWrap = false;
	}

	function addButton(x:Float, y:Float, w:Float, h:Float, text:String, action:Void->Void):LabButton
	{
		final bg:FlxSprite = new FlxSprite(x, y).makeGraphic(Std.int(w), Std.int(h), 0xFF2B2B3E);
		bg.alpha = 0.8;
		add(bg);
		final label:FlxText = makeText(x, y + 4, w, text, 11, FlxColor.WHITE, CENTER);
		final button:LabButton = {x: x, y: y, w: w, h: h, bg: bg, label: label, action: action};
		buttons.push(button);
		return button;
	}

	function makeText(x:Float, y:Float, width:Float, text:String, size:Int, ?color:FlxColor = FlxColor.WHITE,
		?align:FlxTextAlign = FlxTextAlign.LEFT):FlxText
	{
		final label:FlxText = new FlxText(x, y, Std.int(width), text, size);
		label.setFormat(Paths.font('vcr.ttf'), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.scrollFactor.set();
		add(label);
		return label;
	}

	// ----------------------------------------------------------------
	// Input
	// ----------------------------------------------------------------

	function handleKeyboard():Void
	{
		if (controls.BACK)
		{
			exitToMasterMenu();
			return;
		}

		final shift:Bool = FlxG.keys.pressed.SHIFT;
		if (FlxG.keys.justPressed.UP)
		{
			if (shift)
				changeKnob(-1);
			else
				changeSelected(-1);
		}
		if (FlxG.keys.justPressed.DOWN)
		{
			if (shift)
				changeKnob(1);
			else
				changeSelected(1);
		}
		if (FlxG.keys.justPressed.LEFT)
		{
			if (shift)
				nudgeKnob(-1);
			else
				changeSelected(-LIST_ROWS);
		}
		if (FlxG.keys.justPressed.RIGHT)
		{
			if (shift)
				nudgeKnob(1);
			else
				changeSelected(LIST_ROWS);
		}

		if (FlxG.keys.justPressed.SPACE)
			togglePlay();
		if (FlxG.keys.justPressed.TAB)
			toggleLanguage();
		if (FlxG.keys.justPressed.C)
			copyCode();
		if (FlxG.keys.justPressed.L)
			toggleLoop();
		if (FlxG.keys.justPressed.E)
			cycleEase(1);
		if (FlxG.keys.justPressed.R)
			cycleEase(-1);
		if (FlxG.keys.justPressed.ENTER)
			resetKnob();
		if (FlxG.keys.justPressed.X)
		{
			if (shift)
				clearAllTracks();
			else
				clearCurrentTrack();
		}
		if (FlxG.keys.justPressed.ONE)
			setSide(-1);
		if (FlxG.keys.justPressed.TWO)
			setSide(0);
		if (FlxG.keys.justPressed.THREE)
			setSide(1);
	}

	function handleMouse():Void
	{
		final mx:Float = FlxG.mouse.x;
		final my:Float = FlxG.mouse.y;
		var consumed:Bool = false;

		for (button in buttons)
		{
			final hover:Bool = inRect(mx, my, button.x, button.y, button.w, button.h);
			if (button.bg.alpha != (hover ? 1.0 : 0.8))
				button.bg.alpha = hover ? 1 : 0.8;
			if (hover && FlxG.mouse.justPressed)
			{
				button.action();
				consumed = true;
			}
		}
		if (consumed)
			return;

		// Wheel scrolls the percent panel when it does not fit.
		if (FlxG.mouse.wheel != 0 && my > previewY && my < barY && mx > rightX - 6)
			scrollKnobs(FlxG.mouse.wheel < 0 ? 1 : -1);

		if (FlxG.mouse.justPressed)
		{
			final listBottom:Float = listY + LIST_ROWS * LIST_ROW_HEIGHT;
			if (mx >= listX && mx <= listX + LIST_COLUMN_WIDTH * LIST_COLUMNS && my >= listY && my < listBottom)
			{
				final col:Int = Std.int((mx - listX) / LIST_COLUMN_WIDTH);
				final row:Int = Std.int((my - listY) / LIST_ROW_HEIGHT);
				selectModifier(col * LIST_ROWS + row);
			}
			else if (inRect(mx, my, rulerX, rulerY - 8, rulerW, rulerH + 16))
			{
				scrubbing = true;
				playing = false;
				refreshPlayButton();
				phase = clamp01((mx - rulerX) / rulerW) * sectionLength();
			}
			else
			{
				for (slot in 0...knobRows.length)
				{
					final row:LabKnobRow = knobRows[slot];
					if (row.knob == null)
						continue;
					if (inRect(mx, my, row.bar.x, row.label.y - 2, row.bar.width, KNOB_ROW_HEIGHT - 6))
					{
						selectKnobSlot(slot);
						dragging = knobRows[slot];
						applyDrag();
						break;
					}
				}
			}
		}

		if (dragging != null)
		{
			if (FlxG.mouse.pressed)
				applyDrag();
			else
				dragging = null;
		}
		if (scrubbing)
		{
			if (FlxG.mouse.pressed)
				phase = clamp01((mx - rulerX) / rulerW) * sectionLength();
			else
				scrubbing = false;
		}
	}

	function inRect(px:Float, py:Float, x:Float, y:Float, w:Float, h:Float):Bool
	{
		return px >= x && px <= x + w && py >= y && py <= y + h;
	}

	function clamp01(value:Float):Float
	{
		return value < 0 ? 0 : (value > 1 ? 1 : value);
	}

	// ----------------------------------------------------------------
	// Clock + preview
	// ----------------------------------------------------------------

	function updateClock(elapsed:Float):Void
	{
		if (!playing)
			return;
		final length:Float = sectionLength();
		phase += elapsed * (bpm / 60);
		while (phase >= length)
			phase -= length;
		if (phase < 0)
			phase = 0;
	}

	/** Runs every preview arrow through the live modifier chain and writes the result back. */
	function transformArrows():Void
	{
		final msPerBeat:Float = 60000 / Math.max(1, bpm);
		for (arrow in previewArrows)
		{
			final distance:Float = arrow.receptor ? 0 : ghostDistance(arrow);
			final receptorX:Float = field.getReceptorX(arrow.lane, arrow.player);
			final receptorY:Float = field.getReceptorY(arrow.lane, arrow.player);

			params.songTime = phase * msPerBeat;
			params.curBeat = phase;
			params.hitTime = params.songTime;
			params.distance = distance;
			params.lane = arrow.lane;
			params.player = arrow.player;
			params.isTapArrow = !arrow.receptor;
			params.isReceptor = arrow.receptor;
			params.receptorX = receptorX;
			params.receptorY = receptorY;

			basePos.set(receptorX, receptorY + (field.downscroll ? -distance : distance), 0);
			output.visuals.reset();
			field.transform(basePos, params, output);

			arrow.sprite.x = output.pos.x;
			arrow.sprite.y = output.pos.y;
			arrow.sprite.angle = output.visuals.angleZ;
			arrow.sprite.scale.set(output.visuals.scaleX * ARROW_SCALE, output.visuals.scaleY * ARROW_SCALE);
			arrow.sprite.alpha = output.visuals.alpha * (arrow.receptor ? 1 : 0.5);
		}

		playhead.x = rulerX + clamp01(phase / sectionLength()) * (rulerW - playhead.width);
	}

	/** Ghost notes stream toward their receptor; the phase is loop-local so a pass looks the same. */
	function ghostDistance(arrow:LabArrow):Float
	{
		final raw:Float = phase * 0.75 + arrow.lane * 0.13 + arrow.ghost * 0.5 + arrow.player * 0.29;
		final progress:Float = raw - Math.ffloor(raw);
		return 16 + progress * Math.max(16, maxGhostDistance - 16);
	}

	/** Replays every recorded track at the current beat. */
	function applyAutomation():Void
	{
		for (track in tracks)
		{
			if (track.isEmpty())
				continue;
			field.setPercent(track.percent, track.valueAt(phase, easeFn, 0), track.player);
		}
	}

	// ----------------------------------------------------------------
	// Selection
	// ----------------------------------------------------------------

	function currentModifier():LabModifier
	{
		return catalog[selected];
	}

	function currentKnob():Null<LabKnob>
	{
		final knobs:Array<LabKnob> = currentModifier().knobs;
		return knobs.length == 0 ? null : knobs[selectedKnob % knobs.length];
	}

	/** Installs the selected modifier so its percents actually transform the preview. */
	function ensureModifier():Void
	{
		if (field == null)
			return;
		final name:String = currentModifier().name;
		if (!field.hasModifier(name))
			field.addModifier(name);
	}

	function selectModifier(index:Int):Void
	{
		if (index < 0 || index >= catalog.length || index == selected)
			return;
		selected = index;
		selectedKnob = 0;
		knobScroll = 0;
		ensureModifier();
		refreshSelection();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);
	}

	function changeSelected(delta:Int):Void
	{
		final count:Int = catalog.length;
		selectModifier(((selected + delta) % count + count) % count);
	}

	function selectKnobSlot(slot:Int):Void
	{
		final index:Int = knobScroll + slot;
		if (currentKnob() == null || index >= currentModifier().knobs.length)
			return;
		if (selectedKnob == index)
			return;
		selectedKnob = index;
		refreshKnobs();
	}

	function changeKnob(delta:Int):Void
	{
		final knobs:Array<LabKnob> = currentModifier().knobs;
		if (knobs.length == 0)
			return;
		selectedKnob = ((selectedKnob + delta) % knobs.length + knobs.length) % knobs.length;
		ensureKnobVisible();
		refreshKnobs();
	}

	function scrollKnobs(delta:Int):Void
	{
		final knobs:Array<LabKnob> = currentModifier().knobs;
		final maxScroll:Int = Std.int(Math.max(0, knobs.length - KNOB_SLOTS));
		final next:Int = Std.int(Math.max(0, Math.min(maxScroll, knobScroll + delta)));
		if (next == knobScroll)
			return;
		knobScroll = next;
		if (selectedKnob < knobScroll)
			selectedKnob = knobScroll;
		if (selectedKnob >= knobScroll + KNOB_SLOTS)
			selectedKnob = knobScroll + KNOB_SLOTS - 1;
		refreshKnobs();
	}

	function ensureKnobVisible():Void
	{
		if (selectedKnob < knobScroll)
			knobScroll = selectedKnob;
		if (selectedKnob >= knobScroll + KNOB_SLOTS)
			knobScroll = selectedKnob - KNOB_SLOTS + 1;
		knobScroll = Std.int(Math.max(0, knobScroll));
	}

	function setSide(player:Int):Void
	{
		if (side == player)
			return;
		side = player;
		dragging = null;
		refreshKnobs();
		refreshRuler();
		refreshStatus();
	}

	// ----------------------------------------------------------------
	// Tracks
	// ----------------------------------------------------------------

	function trackFor(modifier:String, percent:String, player:Int, create:Bool = false):Null<ModchartLabTrack>
	{
		for (track in tracks)
		{
			if (track.matches(modifier, percent, player))
				return track;
		}
		if (!create)
			return null;
		final created:ModchartLabTrack = new ModchartLabTrack(modifier, percent, player);
		tracks.push(created);
		return created;
	}

	function currentTrack(create:Bool = false):Null<ModchartLabTrack>
	{
		final knob:Null<LabKnob> = currentKnob();
		if (knob == null)
			return null;
		return trackFor(currentModifier().name, knob.percent, side, create);
	}

	function hasAnyTrack(modifier:String):Bool
	{
		for (track in tracks)
		{
			if (!track.isEmpty() && track.modifier.toLowerCase() == modifier.toLowerCase())
				return true;
		}
		return false;
	}

	function totalKeys():Int
	{
		var total:Int = 0;
		for (track in tracks)
			total += track.count();
		return total;
	}

	/** Value currently shown for a knob (live automation when a track exists). */
	function knobValue(knob:LabKnob):Float
	{
		final track:Null<ModchartLabTrack> = trackFor(currentModifier().name, knob.percent, side, false);
		if (track != null && !track.isEmpty())
			return track.valueAt(phase, easeFn, knob.value);
		return field.getPercent(knob.percent, side < 0 ? 0 : side);
	}

	/** Writes a value for the selected knob, optionally recording it at the playhead. */
	function writeKnob(value:Float, record:Bool):Void
	{
		final knob:Null<LabKnob> = currentKnob();
		if (knob == null)
			return;
		final clamped:Float = Math.max(knob.min, Math.min(knob.max, value));
		field.setPercent(knob.percent, clamped, side);
		if (!record)
			return;

		final track:ModchartLabTrack = trackFor(currentModifier().name, knob.percent, side, true);
		final snapped:Float = Math.min(sectionLength(), Math.max(0, Math.round(phase / KEY_GRID) * KEY_GRID));
		if (track.record(snapped, clamped, KEY_GRID * 0.5))
		{
			exportDirty = true;
			rulerDirty = true;
			listDirty = true;
		}
	}

	function applyDrag():Void
	{
		if (dragging == null || dragging.knob == null)
			return;
		final bar:FlxSprite = dragging.bar;
		final t:Float = bar.width <= 0 ? 0 : clamp01((FlxG.mouse.x - bar.x) / bar.width);
		writeKnob(dragging.knob.min + t * (dragging.knob.max - dragging.knob.min), true);
	}

	function nudgeKnob(direction:Int):Void
	{
		final knob:Null<LabKnob> = currentKnob();
		if (knob == null)
			return;
		final step:Float = FlxG.keys.pressed.CONTROL ? knob.step * 5 : knob.step;
		writeKnob(knobValue(knob) + direction * step, true);
	}

	function resetKnob():Void
	{
		final knob:Null<LabKnob> = currentKnob();
		if (knob == null)
			return;
		writeKnob(knob.value, true);
	}

	function clearCurrentTrack():Void
	{
		final track:Null<ModchartLabTrack> = currentTrack(true);
		if (track == null)
			return;
		track.clear();
		final knob:Null<LabKnob> = currentKnob();
		if (knob != null)
			field.setPercent(knob.percent, knob.value, side);
		exportDirty = true;
		refreshRuler();
		refreshListLabels();
		refreshKnobValues();
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.3);
	}

	function clearAllTracks():Void
	{
		for (track in tracks)
			track.clear();
		manager.clear();
		ensureModifier();
		dragging = null;
		exportDirty = true;
		refreshRuler();
		refreshListLabels();
		refreshKnobValues();
		FlxG.sound.play(Paths.sound('cancelMenu'), 0.3);
	}

	// ----------------------------------------------------------------
	// Transport + options
	// ----------------------------------------------------------------

	function sectionLength():Float
	{
		return options.length > 0 ? options.length : MIN_LENGTH;
	}

	function togglePlay():Void
	{
		playing = !playing;
		refreshPlayButton();
	}

	function setBpm(value:Float):Void
	{
		bpm = Math.max(MIN_BPM, Math.min(MAX_BPM, value));
		field.crochet = 60000 / bpm;
		refreshStatus();
	}

	function setStart(delta:Float):Void
	{
		options.startBeat = Math.max(0, options.startBeat + delta);
		exportDirty = true;
		refreshStatus();
		refreshRulerLabel();
	}

	function setLength(delta:Float):Void
	{
		options.length = Math.max(MIN_LENGTH, Math.min(MAX_LENGTH, sectionLength() + delta));
		for (track in tracks)
			track.clip(sectionLength());
		if (phase > sectionLength())
			phase = sectionLength();
		exportDirty = true;
		rebuildBeatTicks();
		refreshRuler();
		refreshStatus();
		refreshRulerLabel();
	}

	function cycleEase(delta:Int):Void
	{
		easeName = ModchartLabExport.nextEase(easeName, delta);
		easeFn = ModchartEase.byName(easeName);
		exportDirty = true;
		refreshStatus();
	}

	function toggleLanguage():Void
	{
		options.language = options.language == Lua ? Python : Lua;
		exportDirty = true;
		setLabel(langButton.label, (options.language == Lua ? 'Lua' : 'Python') + ' [TAB]');
	}

	function toggleLoop():Void
	{
		options.loop = !options.loop;
		exportDirty = true;
		setLabel(loopButton.label, 'Loop: ' + (options.loop ? 'on' : 'off'));
	}

	function copyCode():Void
	{
		final code:String = ModchartLabExport.generate(tracks, options);
		final copied:Bool = setClipboard(code);
		copyNote = copied ? 'COPIED' : saveCopyFile(code);
		copiedTimer = 2;
		FlxG.sound.play(Paths.sound(copied ? 'confirmMenu' : 'cancelMenu'), 0.4);
		refreshStatus();
	}

	function setClipboard(text:String):Bool
	{
		try
		{
			lime.system.Clipboard.text = text;
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	/**
	 * Last resort for locked-down clipboards (some Linux sessions, kiosk
	 * builds): the script lands next to the game binary instead of being lost.
	 */
	static function saveCopyFile(code:String):String
	{
		#if sys
		try
		{
			sys.io.File.saveContent(SAVED_COPY_FILE, code + '\n');
			return 'SAVED TO ' + SAVED_COPY_FILE;
		}
		catch (e:Dynamic)
		{
			return 'CLIPBOARD BLOCKED';
		}
		#else
		return 'CLIPBOARD BLOCKED';
		#end
	}

	function exitToMasterMenu():Void
	{
		if (exiting)
			return;
		exiting = true;
		FlxG.mouse.visible = false;
		FlxG.switchState(new MasterEditorMenu());
		FlxG.sound.playMusic(Paths.music('freakyMenu-' + ClientPrefs.daMenuMusic));
	}

	// ----------------------------------------------------------------
	// Refresh
	// ----------------------------------------------------------------

	/** Rebuilds everything that depends on the selected modifier. */
	function refreshSelection():Void
	{
		// The right panel already lists every percent with its value.
		setLabel(modifierHint, currentModifier().hint);
		refreshKnobs();
		refreshListLabels();
		refreshRuler();
		refreshStatus();
		refreshPlayButton();
		refreshEaseLabel();
		exportDirty = true;
	}

	function refreshKnobs():Void
	{
		final modifier:LabModifier = currentModifier();
		final knobs:Array<LabKnob> = modifier.knobs;
		if (selectedKnob >= knobs.length)
			selectedKnob = knobs.length - 1;
		if (selectedKnob < 0)
			selectedKnob = 0;
		ensureKnobVisible();

		setLabel(knobHeader, 'PERCENTS — ' + modifier.label);
		final visible:Int = Std.int(Math.min(KNOB_SLOTS, knobs.length));
		var hint:String = 'Side ' + sideName() + ' (1/2/3)';
		if (knobs.length > KNOB_SLOTS)
			hint += '   rows ' + (knobScroll + 1) + '-' + (knobScroll + visible) + '/' + knobs.length;
		setLabel(sideHint, hint);

		for (slot in 0...KNOB_SLOTS)
		{
			final row:LabKnobRow = knobRows[slot];
			final index:Int = knobScroll + slot;
			if (index >= knobs.length)
			{
				row.knob = null;
				row.label.visible = false;
				row.value.visible = false;
				row.bar.visible = false;
				row.fill.visible = false;
				row.handle.visible = false;
				continue;
			}
			row.knob = knobs[index];
			row.label.visible = true;
			row.value.visible = true;
			row.bar.visible = true;
			row.fill.visible = true;
			row.handle.visible = true;
		}
		refreshKnobValues();
	}

	function refreshKnobValues():Void
	{
		for (slot in 0...knobRows.length)
		{
			final row:LabKnobRow = knobRows[slot];
			if (row.knob == null)
				continue;
			final knob:LabKnob = row.knob;
			final range:Float = knob.max - knob.min;
			final value:Float = knobValue(knob);
			final t:Float = range <= 0 ? 0 : clamp01((value - knob.min) / range);
			final track:Null<ModchartLabTrack> = trackFor(currentModifier().name, knob.percent, side, false);
			final keys:Int = track == null ? 0 : track.count();
			final selectedRow:Bool = knobScroll + slot == selectedKnob;

			setLabel(row.label, knob.percent + (keys > 0 ? ' (' + keys + ')' : ''));
			setLabel(row.value, ModchartLabExport.number(value));
			final labelColor:FlxColor = selectedRow ? FlxColor.WHITE : 0xFFB4B4C8;
			final fillColor:FlxColor = selectedRow ? 0xFF7DD3FC : 0xFF4C4C7A;
			if (row.label.color != labelColor)
				row.label.color = labelColor;
			if (row.fill.color != fillColor)
				row.fill.color = fillColor;
			row.fill.scale.set(Math.max(1, row.bar.width * t), 1);
			row.handle.x = row.bar.x + t * Math.max(0, row.bar.width - row.handle.width);
		}
	}

	function refreshListLabels():Void
	{
		listDirty = false;
		final col:Int = Std.int(selected / LIST_ROWS);
		final row:Int = selected % LIST_ROWS;
		listHighlight.x = listX + col * LIST_COLUMN_WIDTH - 2;
		listHighlight.y = listY + row * LIST_ROW_HEIGHT - 2;

		for (i in 0...listRows.length)
		{
			final modifier:LabModifier = catalog[i];
			final tracked:Bool = hasAnyTrack(modifier.name);
			setLabel(listRows[i], modifier.label + (tracked ? ' *' : ''));
			final color:FlxColor = i == selected ? FlxColor.WHITE : (tracked ? 0xFF9FE3B0 : 0xFFB4B4C8);
			if (listRows[i].color != color)
				listRows[i].color = color;
		}
	}

	function refreshStatus():Void
	{
		final mode:String = options.loop ? 'loop' : 'once';
		final copied:String = copiedTimer > 0 ? '   ' + copyNote : '';
		setLabel(bpmLabel, 'BPM ' + ModchartLabExport.number(bpm));
		setLabel(easeLabel, 'Ease ' + easeName);
		setLabel(statusText, 'Start ' + ModchartLabExport.number(options.startBeat) + '   Len ' + ModchartLabExport.number(sectionLength()) + '   Side '
			+ sideName() + '   Keys ' + totalKeys() + '   Export ' + mode + ' (' + (options.language == Lua ? 'Lua' : 'Python') + ')' + copied);
	}

	function refreshPlayButton():Void
	{
		setLabel(playButton.label, (playing ? 'Pause' : 'Play') + ' [SPACE]');
	}

	function refreshEaseLabel():Void
	{
		setLabel(easeLabel, 'Ease ' + easeName);
	}

	function refreshRulerLabel():Void
	{
		final beat:Float = options.startBeat + phase;
		setLabel(rulerLabel, 'beat ' + ModchartLabExport.number(roundTo(beat, 0.01)) + '   ·   ' + (playing ? 'playing' : 'paused')
			+ '   ·   click to scrub');
	}

	function rebuildBeatTicks():Void
	{
		final length:Float = sectionLength();
		final beats:Int = Math.ceil(length);
		for (i in 0...beatTicks.length)
		{
			final tick:FlxSprite = beatTicks[i];
			if (i > beats)
			{
				tick.exists = false;
				tick.visible = false;
				continue;
			}
			tick.exists = true;
			tick.visible = true;
			tick.x = rulerX + (i / length) * (rulerW - tick.width);
			tick.y = rulerY + 2;
		}
	}

	/** Moves the keyframe ticks of the selected track onto the ruler. */
	function refreshRuler():Void
	{
		rulerDirty = false;
		final track:Null<ModchartLabTrack> = currentTrack(false);
		var used:Int = 0;
		if (track != null)
		{
			for (key in track.keys)
			{
				if (used >= keyTicks.length)
					break;
				final tick:FlxSprite = keyTicks[used];
				tick.exists = true;
				tick.visible = true;
				tick.x = rulerX + (key.beat / sectionLength()) * (rulerW - tick.width);
				tick.y = rulerY;
				used++;
			}
		}
		for (i in used...keyTicks.length)
		{
			keyTicks[i].exists = false;
			keyTicks[i].visible = false;
		}
	}

	function refreshExportIfNeeded():Void
	{
		if (!exportDirty)
			return;
		exportDirty = false;

		final code:String = ModchartLabExport.generate(tracks, options);
		final lines:Array<String> = code.split('\n');

		// The box shows the calls, not the boilerplate comments above them, and
		// in loop mode it jumps to the callback that holds the tweens. C still
		// copies the whole fragment.
		var from:Int = options.loop ? callbackLine(lines, options.callbackName) : -1;
		if (from < 0)
			from = 0;
		while (from < lines.length && isBoilerplate(lines[from]))
			from++;
		if (from >= lines.length)
			from = Std.int(Math.max(0, lines.length - CODE_LINES));

		// One line is spent on a marker when the box starts mid-script.
		final budget:Int = from > 0 ? CODE_LINES - 1 : CODE_LINES;
		final shown:Array<String> = [];
		for (i in from...lines.length)
		{
			if (shown.length >= budget)
				break;
			shown.push(lines[i]);
		}
		var text:String = from > 0 ? '... ' + from + ' lines above' : '';
		text = (text.length > 0 ? text + '\n' : '') + shown.join('\n');
		if (lines.length - from > budget)
			text += '\n... ' + (lines.length - from - budget) + ' more (C copies all ' + lines.length + ' lines)';
		setLabel(codeText, text);
	}

	function sideName():String
	{
		return switch (side)
		{
			case 0: 'OPPONENT';
			case 1: 'PLAYER';
			default: 'BOTH';
		}
	}

	static function roundTo(value:Float, grid:Float):Float
	{
		return grid <= 0 ? value : Math.round(value / grid) * grid;
	}

	/** Index of the generated callback definition, or `-1` when the mode has none. */
	static function callbackLine(lines:Array<String>, name:String):Int
	{
		final lua:String = 'function ' + name + '(';
		final python:String = 'def ' + name + '(';
		for (i in 0...lines.length)
		{
			final trimmed:String = lines[i].trim();
			if (trimmed.startsWith(lua) || trimmed.startsWith(python))
				return i;
		}
		return -1;
	}

	/** Generated comment/blank lines the code box skips. */
	static function isBoilerplate(line:String):Bool
	{
		final trimmed:String = line.trim();
		return trimmed.length == 0 || trimmed.startsWith('--') || trimmed.startsWith('#');
	}

	static function setLabel(target:FlxText, text:String):Void
	{
		if (target.text != text)
			target.text = text;
	}
}
