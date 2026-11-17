package objects;

import backend.ScreenLayout;

import shaders.RGBPalette.RGBShaderReference;

import backend.Paths;
import backend.ClientPrefs;
import play.PlayState;
import shaders.RGBPalette;

// Galaxy port (modcharts)
import flixel.graphics.FlxGraphic;
import modcharts.RenderPath;
import openfl.Vector;

class StrumNote extends FlxSprite
{
	// ---- Galaxy port (modcharts): 3D render state ----
	public var spec:Int = 0;
	public var mustBeKilled:Bool = false;
	public var rendermode:Int = 0;
	public var z:Float = 200 / 0.7;
	public var wx:Float = 0;
	public var wy:Float = 0;
	public var verticles:Vector<Float>;
	public var uvtData:Vector<Float>;
	public var renderer:RenderPath;
	public var gpix:FlxGraphic = null;
	public var oalp:Float = 1;
	public var oanim:String = "";
	var galInited:Bool = false;
	private static var galAlphas:Map<Int, Map<String, Map<Int, Array<Float>>>> = new Map();
	private static var galIndexes:Map<Int, Map<String, Map<Int, Array<Int>>>> = new Map();
	private static var galGlist:Array<FlxGraphic> = [];

	/** Galaxy: discard cached triangle-render frames (called by PlayMoving.reset). */
	public static function refresh()
	{
		for (i in galGlist)
			i.destroy();
		galAlphas = new Map();
		galIndexes = new Map();
		galGlist = [];
	}
	public var rgbShader:RGBShaderReference;
	public var notes_angle:Null<Float> = null;
	public var resetAnim:Float = 0;
	public var noteData:Int = 0;
	public var direction:Float = 90;//plan on doing scroll directions soon -bb
	public var downScroll:Bool = false;//plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;

	public var player:Int;
	public var ogNoteskin:String = null;

	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = (value != null ? value : "noteskins/NOTE_assets" + NoteHelpers.getNoteSkinPostfix());
			reloadNote();
		}
		return value;
	}
	public var useRGBShader:Bool = true;

	public function getAngle() {
		return (notes_angle == null ? angle : notes_angle);
	}

	public function new(x:Float, y:Float, leData:Int, player:Int, ?inEditor:Bool = false) {
		rgbShader = new RGBShaderReference(this, NoteHelpers.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB || !ClientPrefs.enableColorShader) useRGBShader = false;

		var arr:Array<FlxColor> = NoteColors.laneRGB(leData, PlayState.isPixelStage);
		if(arr != null && arr.length >= 3 && useRGBShader)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}
		noteData = leData;
		this.player = player;
		this.noteData = leData;
		super(x, y);

		var skin:String = null;
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;

		var customSkin:String = skin + NoteHelpers.getNoteSkinPostfix();
		final skinDirectory:String = PlayState.isPixelStage ? 'pixelUI/' : '';
		if(Paths.fileExists('images/$skinDirectory$customSkin.png', IMAGE)) skin = customSkin;

		texture = skin; //Load texture and anims
		ogNoteskin = skin;

		scrollFactor.set();
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.globalAntialiasing;
			setGraphicSize(Std.int(width * 0.7));

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	public function postAddedToGroup() {
		playAnim('static');
		x += Note.swagWidth * noteData;
		x += 50;
		// Keep the two 16:9 note lanes together in the center of a wider HUD.
		x += ScreenLayout.contentLeft(FlxG.width) + (ScreenLayout.BASE_WIDTH / 2) * player;
		ID = noteData;
	}

	override function update(elapsed:Float) {
		if (ClientPrefs.ffmpegMode) elapsed = 1 / ClientPrefs.targetFPS;
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false, ?r:FlxColor, ?g:FlxColor, ?b:FlxColor) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		if(useRGBShader)
		{
			rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
			if (r != null && g != null && b != null) updateRGBColors(r, g, b);
		} else if (!useRGBShader && rgbShader != null) rgbShader.enabled = false;
	}
	public function updateNoteSkin(noteskin:String) {
		// An empty character skin means the chart's original skin, not always
		// NOTE_assets (the chart may have supplied a custom or pixel skin).
		final target:String = noteskin == null || noteskin.length == 0 || noteskin == ogNoteskin
			? ogNoteskin : "noteskins/" + noteskin;
		if (target != null && texture != target) texture = target;
	}

	public function updateRGBColors(?r:FlxColor, ?g:FlxColor, ?b:FlxColor) {
        if (rgbShader != null && useRGBShader)
		{
			rgbShader.r = r;
			rgbShader.g = g;
			rgbShader.b = b;
		}
	}
	public function resetRGB()
	{
		if (rgbShader != null && animation.curAnim != null && animation.curAnim.name == 'static')
		{
			switch (ClientPrefs.noteColorStyle)
			{
				case 'Quant-Based', 'Rainbow', 'Char-Based':
					rgbShader.r = 0xFFF9393F;
					rgbShader.g = 0xFFFFFFFF;
					rgbShader.b = 0xFF651038;
				case 'Grayscale':
					rgbShader.r = 0xFFA0A0A0;
					rgbShader.g = FlxColor.WHITE;
					rgbShader.b = 0xFF424242;
				default:

			}
			rgbShader.enabled = false;
		}
	}

	// ---- Galaxy port (modcharts): 3D triangle rendering ----

	public function scaleW()
	{
		scale.set(1, 1);
		updateHitbox();
		var lt:Array<Float> = NoteObject.toScreen(wx - width / 2, wy - height / 2, z);
		var rb:Array<Float> = NoteObject.toScreen(wx + width / 2, wy + height / 2, z);
		setGraphicSize(Std.int(rb[0] - lt[0]), Std.int(rb[1] - lt[1]));
		if (Std.int(rb[0] - lt[0]) < 1 || Std.int(rb[1] - lt[1]) < 1 || z < 0)
		{
			scale.set(0, 0);
		}
		updateHitbox();
		x = lt[0];
		y = lt[1];
	}

	public function render(over:Array<Float>, ?ouvt:Array<Float> = null)
	{
		if (!galInited)
		{
			scale.set(1, 1);
			if (animation.curAnim != null && animation.curAnim.name == 'static')
			{
				updateHitbox();
				galInited = true;
			}
		}
		rendermode = 1;
		offset.set();
		x = 0;
		y = 0;
		var auvt:Array<Float> = [0, 0, 1, 0, 0, 1, 1, 1];
		if (ouvt != null)
			auvt = ouvt.copy();
		verticles = new Vector(8, true, over);
		uvtData = new Vector(auvt.length, true, auvt);
	}

	public function pathrender()
	{
		if (!galInited)
		{
			scale.set(1, 1);
			if (animation.curAnim != null && animation.curAnim.name == 'static')
			{
				updateHitbox();
				galInited = true;
			}
		}
		offset.set();
		rendermode = 2;
		x = 0;
		y = 0;
	}

	override function draw()
	{
		switch (rendermode)
		{
			case 2:
				if (renderer == null || alpha <= 0 || !visible || !active)
					return;
				scale.set(1, 1);
				updateHitbox();
				var inc:Vector<Int> = new Vector(6, true, [0, 1, 2, 1, 3, 2]);
				var gdata:FlxGraphic = mapData();
				var rem:Float = 1 - renderer.bili;
				while (rem + 0.1 < 1)
				{
					for (camera in cameras)
					{
						if (!camera.visible || !camera.exists)
						{
							continue;
						}
						var start:Float = rem;
						var end:Float = rem + 0.1;
						var lists:Array<Array<Float>> = renderer.start(start, end);
						var v:Vector<Float> = new Vector(8, true, lists[0]);
						var u:Vector<Float> = new Vector(lists[1].length, true, lists[1]);
						if (end > 1)
							end = 1;
						getScreenPosition(_point, camera).subtractPoint(offset);
						camera.drawTriangles(gdata, v, inc, u, null, _point, blend, false, antialiasing);
						rem = end;
					}
				}
			case 1:
				if (verticles == null || uvtData == null || alpha <= 0 || !visible || !active)
					return;
				scale.set(1, 1);
				updateHitbox();
				var inc1:Vector<Int> = new Vector(6, true, [0, 1, 2, 1, 3, 2]);
				var gdata1:FlxGraphic = mapData();
				for (camera in cameras)
				{
					if (!camera.visible || !camera.exists)
					{
						continue;
					}
					getScreenPosition(_point, camera).subtractPoint(offset);
					camera.drawTriangles(gdata1, verticles, inc1, uvtData, null, _point, blend, false, antialiasing);
				}
			default:
				galInited = false;
				super.draw();
		}
	}

	function mapData():FlxGraphic
	{
		if (gpix == null || alpha != oalp || !animation.curAnim.finished || oanim != animation.curAnim.name)
		{
			if (!galAlphas.exists(ID))
			{
				galAlphas.set(ID, new Map());
				galIndexes.set(ID, new Map());
			}
			if (!galAlphas.get(ID).exists(animation.curAnim.name))
			{
				galAlphas.get(ID).set(animation.curAnim.name, new Map());
				galIndexes.get(ID).set(animation.curAnim.name, new Map());
			}
			if (!galAlphas.get(ID)
				.get(animation.curAnim.name)
				.exists(animation.curAnim.curFrame))
			{
				galAlphas.get(ID)
					.get(animation.curAnim.name)
					.set(animation.curAnim.curFrame, []);
				galIndexes.get(ID)
					.get(animation.curAnim.name)
					.set(animation.curAnim.curFrame, []);
			}
			if (!galAlphas.get(ID)
				.get(animation.curAnim.name)
				.get(animation.curAnim.curFrame)
				.contains(alpha))
			{
				var pix:FlxGraphic = FlxGraphic.fromFrame(frame, true);
				var nalp:Array<Float> = galAlphas.get(ID).get(animation.curAnim.name).get(animation.curAnim.curFrame);
				var nindex:Array<Int> = galIndexes.get(ID).get(animation.curAnim.name).get(animation.curAnim.curFrame);
				pix.bitmap.colorTransform(pix.bitmap.rect, colorTransform);
				galGlist.push(pix);
				nalp.push(alpha);
				nindex.push(galGlist.length - 1);
				galAlphas.get(ID)
					.get(animation.curAnim.name)
					.set(animation.curAnim.curFrame, nalp);
				galIndexes.get(ID)
					.get(animation.curAnim.name)
					.set(animation.curAnim.curFrame, nindex);
			}
			var dex = galAlphas.get(ID)
				.get(animation.curAnim.name)
				.get(animation.curAnim.curFrame)
				.indexOf(alpha);
			gpix = galGlist[
				galIndexes.get(ID)
					.get(animation.curAnim.name)
					.get(animation.curAnim.curFrame)[dex]];
			oalp = alpha;
			oanim = animation.curAnim.name;
		}
		return gpix;
	}
}
