package states.substates;

#if MODS_ALLOWED
import backend.ModSecurity;
import backend.ModSecurity.ModSecurityStatus;
import backend.MusicBeatSubstate;
import backend.ViewportVisuals;
import flixel.util.FlxSpriteUtil;
import objects.Alphabet;
import states.ModsMenuState.MenuButton;
import states.ModsMenuState.ModItem;
import states.helpers.ModInfoFlow;
import states.helpers.ModInfoFlow.ModInfoAction;

/**
 * "Mod Info" panel of the Mods menu: what the selected mod is, and whether
 * ModSecurity (the script sandbox, see `backend.ModSecurity`) is on for it.
 *
 * ModSecurity is on for every mod by default. The switch here is the player's
 * own decision for this one mod and wins over the mod's `pack.json`. Turning
 * it off asks first, because the mod's scripts then run with full engine
 * privileges (the rules are in `states.helpers.ModInfoFlow`). The choice is
 * saved right away (`modSecurity.txt`) and is used the next time that mod's
 * scripts are loaded.
 *
 * Mods get no hook into this panel: it loads no `data/states/` script and its
 * buttons have no click callbacks, input is read in `update()` only. The members
 * that pick the mod and apply the switch are `@:unreflective`, like
 * `backend.ModSecurity` itself, so that a script which gets hold of this object
 * on a native build finds nothing to call. What the mod wrote about itself is
 * printed as one clipped line (its name) or as rule ids only (its `pack.json`
 * exceptions), so it cannot add text of its own to the panel.
 */
class ModInfoSubState extends MusicBeatSubstate
{
	static inline final PANEL_WIDTH:Int = 900;
	static inline final PANEL_HEIGHT:Int = 600;
	static inline final PADDING:Int = 30;
	static inline final BUTTON_WIDTH:Int = 300;
	static inline final BUTTON_HEIGHT:Int = 80;
	static inline final BUTTON_GAP:Int = 40;

	/** Longest list of `pack.json` exceptions spelled out before "+N more". */
	static inline final MAX_LISTED_RULES:Int = 4;

	static inline final COLOR_ON:FlxColor = 0xFF7CFC8A;
	static inline final COLOR_OFF:FlxColor = 0xFFFF6666;
	static inline final COLOR_ASK:FlxColor = 0xFFFFD166;

	/** Resting colour of the plain buttons: the menu's black would vanish on the dark panel. */
	static inline final COLOR_BUTTON:FlxColor = 0xFF808080;

	/** Mod folder the switch applies to. Hidden from scripts so the panel cannot be re-aimed. */
	@:unreflective var folder:String;
	var modName:String;
	var modEnabled:Bool;
	var runsGlobally:Bool;
	var mustRestart:Bool;
	var onChanged:Void->Void;

	var status:ModSecurityStatus;

	/** Focus and confirmation state. Hidden from scripts so "Yes" cannot be pre-selected. */
	@:unreflective var flow:ModInfoFlow;
	var saveFailed:Bool = false;

	/** Ignores input for a moment, so the press that opened the panel cannot act in it. */
	var inputDelay:Float = 0.15;

	var bg:FlxSprite;
	var panel:FlxSprite;
	var title:Alphabet;
	var nameText:FlxText;
	var detailsText:FlxText;
	var securityTitle:FlxText;
	var stateText:FlxText;
	var bodyText:FlxText;
	var noteText:FlxText;
	var lineTop:FlxSprite;
	var lineBottom:FlxSprite;

	var buttonTurnOff:MenuButton;
	var buttonTurnOn:MenuButton;
	var buttonBack:MenuButton;
	var buttonYes:MenuButton;
	var buttonNo:MenuButton;

	/**
	 * @param mod         the mod selected in the Mods menu
	 * @param modEnabled  whether that mod is currently switched on in the list
	 * @param onChanged   called after the ModSecurity choice changed
	 */
	public function new(mod:ModItem, modEnabled:Bool, ?onChanged:Void->Void)
	{
		super();
		// The panel that turns the sandbox off must not run a mod's
		// `data/states/ModInfoSubState.hx`.
		scriptsAllowed = false;

		folder = mod.folder;
		modName = mod.name;
		this.modEnabled = modEnabled;
		runsGlobally = mod.pack != null && mod.pack.runsGlobally == true;
		mustRestart = mod.mustRestart;
		this.onChanged = onChanged;
		status = ModSecurity.getStatus(folder);
		flow = new ModInfoFlow(status.enabled);
	}

	override function create()
	{
		super.create();

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		// A light rim keeps the panel apart from the dimmed menu behind it.
		panel = new FlxSprite().makeGraphic(PANEL_WIDTH, PANEL_HEIGHT, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(panel, 0, 0, PANEL_WIDTH, PANEL_HEIGHT, 25, 25, 0xFF9A9AB0);
		FlxSpriteUtil.drawRoundRect(panel, 3, 3, PANEL_WIDTH - 6, PANEL_HEIGHT - 6, 22, 22, 0xFF15151C);
		panel.alpha = 0.95;
		add(panel);

		title = new Alphabet(0, 0, 'Mod Info', true);
		title.setScale(0.6);
		add(title);

		// The name and the folder are the mod's own text: one clipped line each.
		var shownFolder:String = ModInfoFlow.oneLine(folder, 48);
		var shownName:String = ModInfoFlow.oneLine(modName, 58);
		nameText = makeText(24);
		nameText.text = shownName.length > 0 ? shownName : shownFolder;
		lineTop = makeLine();

		detailsText = makeText(20);
		detailsText.text = 'Folder:         mods/' + shownFolder
			+ '\nMod enabled:    ' + yesNo(modEnabled)
			+ '\nRuns globally:  ' + yesNo(runsGlobally)
			+ '\nNeeds restart:  ' + yesNo(mustRestart);
		lineBottom = makeLine();

		securityTitle = makeText(20);
		securityTitle.text = 'SCRIPT SECURITY';
		securityTitle.alpha = 0.7;
		stateText = makeText(26);
		bodyText = makeText(20);
		noteText = makeText(16);

		buttonTurnOff = makeButton('TURN OFF', COLOR_OFF);
		buttonTurnOn = makeButton('TURN ON', COLOR_ON);
		buttonBack = makeButton('BACK', COLOR_BUTTON);
		buttonNo = makeButton('NO', COLOR_BUTTON);
		buttonYes = makeButton('YES', COLOR_OFF);

		addVirtualPad(LEFT_RIGHT, A_B);

		ViewportVisuals.fill(bg);
		refresh();
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.fill(bg);
		if(panel != null) layout();
	}

	override function update(elapsed:Float)
	{
		if(bg.alpha < 0.6) bg.alpha = Math.min(0.6, bg.alpha + elapsed * 3);

		// Same rule as the Mods menu: the cursor shows up once the mouse really moves.
		if(!FlxG.mouse.visible && (Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10))
			FlxG.mouse.visible = true;

		if(inputDelay > 0) inputDelay -= elapsed;
		else handleInput();

		super.update(elapsed);
	}

	function handleInput():Void
	{
		var buttons:Array<MenuButton> = [leftButton(), rightButton()];

		// Touch has no cursor. With a mouse, a hidden cursor neither hovers nor clicks.
		var pointerActive:Bool = #if mobile true #else FlxG.mouse.visible #end;
		var pointed:Int = -1;
		if(pointerActive)
			for(i => button in buttons)
				if(FlxG.mouse.overlaps(button)) pointed = i;

		var focusMoved:Bool = false;
		if(controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			flow.toggleFocus();
			focusMoved = true;
		}
		else if(pointed >= 0 && FlxG.mouse.justMoved) focusMoved = flow.focus(pointed);
		if(focusMoved)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			refreshFocus();
		}

		if(controls.BACK) perform(flow.back());
		else if(controls.ACCEPT) perform(flow.accept());
		else if(pointed >= 0 && FlxG.mouse.justPressed) perform(flow.press(pointed));
	}

	/** The only caller of `ModSecurity.setEnabled`; reached from `handleInput()` and nowhere else. */
	@:unreflective function perform(action:ModInfoAction):Void
	{
		switch(action)
		{
			case CLOSE:
				FlxG.sound.play(Paths.sound('cancelMenu'));
				close();

			case ASK:
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				refresh();

			case CANCEL:
				FlxG.sound.play(Paths.sound('cancelMenu'));
				refresh();

			case APPLY(enabled):
				saveFailed = !ModSecurity.setEnabled(folder, enabled);
				status = ModSecurity.getStatus(folder);
				flow.enabled = status.enabled;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				refresh();
				if(onChanged != null) onChanged();
		}
	}

	inline function leftButton():MenuButton
		return flow.confirming ? buttonNo : (flow.enabled ? buttonTurnOff : buttonTurnOn);

	inline function rightButton():MenuButton
		return flow.confirming ? buttonYes : buttonBack;

	/** Rewrites the security texts and shows the button pair for the current state. */
	function refresh():Void
	{
		if(flow.confirming)
		{
			stateText.text = 'Turn ModSecurity OFF for this mod?';
			stateText.color = COLOR_ASK;
			bodyText.text = 'Its scripts will no longer be checked and will run with full engine privileges: '
				+ 'they can read and write your files, start programs and use the network.\n\n'
				+ 'Only do this for a mod you trust.';
		}
		else
		{
			stateText.text = 'ModSecurity: ' + (status.enabled ? 'ON' : 'OFF') + stateOrigin();
			stateText.color = status.enabled ? COLOR_ON : COLOR_OFF;
			bodyText.text = describeState();
		}

		if(saveFailed)
		{
			noteText.text = 'Could not save ' + ModSecurity.PLAYER_OVERRIDES_FILE + ': this choice will not be remembered.';
			noteText.color = COLOR_OFF;
			noteText.alpha = 1;
		}
		else
		{
			noteText.text = 'Used the next time this mod\'s scripts are loaded.';
			noteText.color = FlxColor.WHITE;
			noteText.alpha = 0.7;
		}

		var left:MenuButton = leftButton();
		var right:MenuButton = rightButton();
		for(button in [buttonTurnOff, buttonTurnOn, buttonBack, buttonYes, buttonNo])
			button.visible = button.active = (button == left || button == right);

		layout();
		refreshFocus();
	}

	function refreshFocus():Void
	{
		var buttons:Array<MenuButton> = [leftButton(), rightButton()];
		for(i => button in buttons)
		{
			button.onFocus = (i == flow.selected);
			// Showing a button makes both of its labels visible again; let it pick one.
			button.setButtonVisibility(button.onFocus);
		}
	}

	/** Who decided the current state, shown next to ON/OFF. */
	function stateOrigin():String
	{
		if(status.playerOverride != null) return ' (your choice)';
		return status.packEnabled ? ' (default)' : ' (set by the mod)';
	}

	function describeState():String
	{
		if(!status.enabled)
		{
			var who:String = status.playerOverride != null
				? 'You turned ModSecurity off for this mod.'
				: 'This mod\'s pack.json turns ModSecurity off.';
			return who + ' Its scripts are not checked and run with full engine privileges: '
				+ 'they can read and write files, start programs and use the network.';
		}

		var text:String = !status.packEnabled
			? 'This mod\'s pack.json asks to run without ModSecurity, but you turned it on. Its Lua, Python and HScript '
				+ 'files are checked before they run, and risky ones are blocked.'
			: 'Lua, Python and HScript files from this mod are checked before they run. Scripts that touch files, '
				+ 'the network, other programs or engine internals are blocked.';

		// pack.json is the mod's own text: only rule ids are printed here.
		var rules:Array<String> = ModInfoFlow.printableRules(status.allowlist);
		if(rules.length > 0)
		{
			var listed:Array<String> = rules.slice(0, MAX_LISTED_RULES);
			var more:Int = rules.length - listed.length;
			text += '\n\nExceptions in its pack.json: ' + listed.join(', ') + (more > 0 ? ' (+$more more)' : '');
		}
		return text;
	}

	/** Positions everything from the centered panel, so a resize only needs this. */
	function layout():Void
	{
		panel.screenCenter();
		var left:Float = panel.x + PADDING;
		var y:Float = panel.y + 22;

		title.setPosition(left, y);
		y = Math.max(y + 44, title.findMaxY()) + 8;
		nameText.setPosition(left, y);
		y += nameText.height + 6;
		lineTop.setPosition(left, y);
		y += 12;
		detailsText.setPosition(left, y);
		y += detailsText.height + 10;
		lineBottom.setPosition(left, y);
		y += 12;
		securityTitle.setPosition(left, y);
		y += securityTitle.height + 2;
		stateText.setPosition(left, y);
		y += stateText.height + 6;
		bodyText.setPosition(left, y);

		// Kept between the virtual pad's D-pad (left) and A/B (right) on touch screens.
		var buttonsY:Float = panel.y + PANEL_HEIGHT - BUTTON_HEIGHT - 20;
		var leftX:Float = panel.x + (PANEL_WIDTH - BUTTON_WIDTH * 2 - BUTTON_GAP) / 2;
		var rightX:Float = leftX + BUTTON_WIDTH + BUTTON_GAP;
		for(button in [buttonTurnOff, buttonTurnOn, buttonNo]) button.setPosition(leftX, buttonsY);
		for(button in [buttonBack, buttonYes]) button.setPosition(rightX, buttonsY);

		noteText.setPosition(left, buttonsY - noteText.height - 8);
	}

	function makeText(size:Int):FlxText
	{
		var text:FlxText = new FlxText(0, 0, PANEL_WIDTH - PADDING * 2, '', size);
		text.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, LEFT);
		add(text);
		return text;
	}

	function makeLine():FlxSprite
	{
		var line:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		line.setGraphicSize(PANEL_WIDTH - PADDING * 2, 2);
		line.updateHitbox();
		line.alpha = 0.25;
		add(line);
		return line;
	}

	function makeButton(label:String, tint:FlxColor):MenuButton
	{
		// No click callback: update() decides what a press means.
		var button:MenuButton = new MenuButton(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, label);
		button.ignoreCheck = true; // this panel moves the focus, for keyboard and mouse alike
		button.bg.color = tint;
		button.focusChangeCallback = function(focus:Bool) if(!focus) button.bg.color = tint;
		add(button);
		return button;
	}

	static function yesNo(value:Bool):String
		return value ? 'Yes' : 'No';
}
#end
