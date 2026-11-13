package objects;

import backend.MusicBeatSubstate;
import backend.PlayerSettings;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIPopup;
import flixel.ui.FlxButton;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

/**
 * OK/CANCEL pop-up used by the editors, the mod importer and settings import.
 *
 * Both buttons keep their original art but are wrapped in an invisible,
 * enlarged {@link TouchTarget}. For destructive questions (`requireHold`),
 * OK is additionally guarded by {@link HoldToConfirm}: a single tap can no
 * longer delete a mod/save/chart or overwrite every preference. CANCEL is
 * always a plain tap, and keyboard/gamepad ACCEPT works as well (held when
 * guarded).
 */
class Prompt extends MusicBeatSubstate
{
	var selected = 0;
	public var okc:Void->Void;
	public var cancelc:Void->Void;
	var buttons:FlxSprite = new FlxSprite(473.3, 450);
	var theText:String = '';
	var goAnyway:Bool = false;
	var UI_box:FlxUIPopup;
	var panel:FlxSprite;
	var panelbg:FlxSprite;
	var buttonAccept:FlxButton;
	var buttonNo:FlxButton;
	var cornerSize:Int = 10;

	/** Destructive question: OK needs a held press or a second confirmation. */
	var requireHold:Bool = false;
	var okTarget:TouchTarget = null;
	var cancelTarget:TouchTarget = null;
	var holdConfirm:HoldToConfirm = null;

	/**
	 * @param requireHold true for questions whose OK button deletes/overwrites
	 *                    data; the OK press is guarded, CANCEL stays immediate.
	 */
	public function new(promptText:String='', defaultSelected:Int = 0, okCallback:Void->Void,
		cancelCallback:Void->Void, acceptOnDefault:Bool=false, option1:String=null,
		option2:String=null, requireHold:Bool=false)
	{
		selected = defaultSelected;
		okc = okCallback;
		cancelc = cancelCallback;
		theText = promptText;
		this.requireHold = requireHold;
		// "Ignore Progress Warnings" may skip the question, but it must never
		// turn a destructive action back into a single tap.
		goAnyway = acceptOnDefault && !requireHold;

		var op1 = 'OK';
		var op2 = 'CANCEL';

		if (option1 != null) op1 = option1;
		if (option2 != null) op2 = option2;
		buttonAccept = new FlxButton(473.3, 450, op1, null);
		buttonNo = new FlxButton(633.3, 450, op2, null);
		super();
	}

	override public function create():Void
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		super.create();
		if (goAnyway){

			if(okc != null)okc();
			close();

		}else{
		panel = new FlxSprite(0, 0);
		panelbg = new FlxSprite(0, 0);
		makeSelectorGraphic(panel,300,150,0xff999999);
		makeSelectorGraphic(panelbg,304,154,0xff000000);
		panel.scrollFactor.set();
		panel.screenCenter();
		panelbg.scrollFactor.set();
		panelbg.screenCenter();

		add(panelbg);
		add(panel);
		add(buttonAccept);
		add(buttonNo);
		//add(buttons);
		var textField:FlxText = new FlxText(buttonNo.width*2, panel.y, 300, theText, 16);
		textField.alignment = 'center';
		add(textField);
		textField.screenCenter();
		buttonAccept.screenCenter();
		buttonNo.screenCenter();
		buttonAccept.x -= buttonNo.width/1.5;
		buttonAccept.y = panel.y + panel.height-30;
		buttonNo.x += buttonNo.width/1.5;
		buttonNo.y = panel.y + panel.height-30;
		textField.scrollFactor.set();

		installTouchTargets();
		}
	}

	/**
	 * Moves the press handling from the small FlxButtons to enlarged hit areas.
	 * The buttons still draw and highlight exactly as before; only their
	 * callbacks are detached so no single tap can reach the destructive path.
	 */
	function installTouchTargets():Void
	{
		buttonAccept.onUp.callback = null;
		buttonNo.onUp.callback = null;

		var accept:Void->Void = function() {
			if (okc != null) okc();
			close();
		};
		var decline:Void->Void = function() {
			if (cancelc != null) cancelc();
			close();
		};

		if (requireHold)
		{
			holdConfirm = new HoldToConfirm(buttonAccept, accept,
				() -> PlayerSettings.player1.controls.ACCEPT, 'HOLD TO CONFIRM');
			holdConfirm.cameras = cameras;
			add(holdConfirm);
		}
		else
		{
			okTarget = new TouchTarget(buttonAccept, accept);
			okTarget.cameras = cameras;
			add(okTarget);
		}

		cancelTarget = new TouchTarget(buttonNo, decline);
		cancelTarget.cameras = cameras;
		add(cancelTarget);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed); // updates the guard/hit areas first
		var controls = PlayerSettings.player1.controls;
		if (controls.BACK)
		{
			if (holdConfirm != null) holdConfirm.cancel();
			if (cancelc != null) cancelc();
			close();
			return;
		}
		// Guarded prompts let HoldToConfirm consume ACCEPT (held or twice);
		// informational prompts still confirm with one keyboard/gamepad press.
		if (holdConfirm == null && controls.ACCEPT)
		{
			if (okc != null) okc();
			close();
		}
	}

	function makeSelectorGraphic(panel:FlxSprite,w,h,color:FlxColor)
	{
		panel.makeGraphic(w, h, color);
		panel.pixels.fillRect(new Rectangle(0, 190, panel.width, 5), 0x0);

		// Why did i do this? Because i'm a lmao stupid, of course
		// also i wanted to understand better how fillRect works, so I tried it myself lol???
		panel.pixels.fillRect(new Rectangle(0, 0, cornerSize, cornerSize), 0x0);														 //top left
		drawCircleCornerOnSelector(panel,false, false,color);
		panel.pixels.fillRect(new Rectangle(panel.width - cornerSize, 0, cornerSize, cornerSize), 0x0);							 //top right
		drawCircleCornerOnSelector(panel,true, false,color);
		panel.pixels.fillRect(new Rectangle(0, panel.height - cornerSize, cornerSize, cornerSize), 0x0);							 //bottom left
		drawCircleCornerOnSelector(panel,false, true,color);
		panel.pixels.fillRect(new Rectangle(panel.width - cornerSize, panel.height - cornerSize, cornerSize, cornerSize), 0x0); //bottom right
		drawCircleCornerOnSelector(panel,true, true,color);
	}

	function drawCircleCornerOnSelector(panel:FlxSprite,flipX:Bool, flipY:Bool,color:FlxColor)
	{
		var antiX:Float = (panel.width - cornerSize);
		var antiY:Float = flipY ? (panel.height - 1) : 0;
		if(flipY) antiY -= 2;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Std.int(Math.abs(antiY - 8)), 10, 3), color);
		if(flipY) antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Std.int(Math.abs(antiY - 6)),  9, 2), color);
		if(flipY) antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Std.int(Math.abs(antiY - 5)),  8, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Std.int(Math.abs(antiY - 4)),  7, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Std.int(Math.abs(antiY - 3)),  6, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Std.int(Math.abs(antiY - 2)),  5, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Std.int(Math.abs(antiY - 1)),  3, 1), color);
	}

	override public function destroy():Void
	{
		okc = null;
		cancelc = null;
		super.destroy();
	}
}
