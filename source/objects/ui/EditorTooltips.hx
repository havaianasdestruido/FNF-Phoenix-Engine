package objects.ui;

import flixel.FlxObject;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIState;
import flixel.addons.ui.FontDef;
import openfl.text.TextFormat;

/** Camera-aware hover target for flixel-ui editor help. Never draws or handles clicks. */
class EditorTooltips extends FlxUIButton
{
	var owner:FlxUIState;
	var target:FlxObject;
	var help:String;
	var registered:Bool = false;

	/** Attach help, even when the editor builds its controls before super.create(). */
	public static function add(state:FlxUIState, control:FlxObject, text:String):Void
	{
		state.add(new EditorTooltips(state, control, text));
	}

	function new(state:FlxUIState, control:FlxObject, text:String)
	{
		super(0, 0, "", null, false, true);
		owner = state;
		target = control;
		help = text;
	}

	override public function update(elapsed:Float):Void
	{
		// Unlike the manager's default proxy, follow the control's camera as well as
		// its bounds. Character editor UI, for example, uses a separate menu camera.
		x = target.x;
		y = target.y;
		width = target.width;
		height = target.height;
		cameras = target.cameras;
		scrollFactor.copyFrom(target.scrollFactor);
		visible = target.exists && target.visible && target.active;
		super.update(elapsed);

		if (!registered && owner.tooltips != null)
		{
			owner.tooltips.delay = 0.6;
			owner.tooltips.showOnClick = false;
			owner.tooltips.cameras = cameras;
			owner.tooltips.add(this, {
				title: "",
				body: help,
				style: {
					bodyWidth: 260,
					bodyFormat: new FontDef(null, null, null, new TextFormat(null, 12, 0xFFFFFF)),
					background: 0xFF20222B,
					borderColor: 0xFF9298AD
				}
			});
			registered = true;
		}
	}

	/** Only the manager's tooltip is drawn, never this hover target. */
	override public function draw():Void {}

	override public function destroy():Void
	{
		owner = null;
		target = null;
		help = null;
		super.destroy();
	}
}
