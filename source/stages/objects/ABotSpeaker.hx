package stages.objects;
import backend.ClientPrefs;
import backend.Paths;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

class ABotSpeaker extends FlxSpriteGroup
{
	final VIZ_MAX = 7; //ranges from viz1 to viz7
	final VIZ_POS_X:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
	final VIZ_POS_Y:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyeBg:FlxSprite;
	#if flxanimate
	public var eyes:FlxAnimate;
	public var speaker:FlxAnimate;
	#else
	public var eyes:FlxSprite;
	public var speaker:FlxSprite;
	#end

	#if funkin.vis
	var analyzer:SpectralAnalyzer;
	#end
	var volumes:Array<Float> = [];
	/** Only report a mismatched viz atlas once per speaker, not once per bar. */
	var vizAtlasWarned:Bool = false;

	public var snd(default, set):FlxSound;
	function set_snd(changed:FlxSound)
	{
		snd = changed;
		#if funkin.vis
		initAnalyzer();
		#end
		return snd;
	}

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		// A-Bot is background dressing: every piece here is optional, so missing
		// art must degrade to "speaker with no bars" instead of taking the song
		// down. The 2026-11-11 bundle died here with a null object reference on
		// `curAnim.finish()` because the aBotViz spritesheet could not be
		// resolved -- `addByPrefix()` silently adds nothing when the frames are
		// absent, leaving `curAnim` null. Paths now logs which atlas part failed
		// (`[ASSET ATLAS]` in the vlog) so a broken install is diagnosable.
		var antialias = ClientPrefs.globalAntialiasing;

		final bgGraphic = Paths.image('abot/stereoBG');
		if (bgGraphic != null)
		{
			bg = new FlxSprite(90, 20).loadGraphic(bgGraphic);
			bg.antialiasing = antialias;
			add(bg);
		}

		var vizX:Float = 0;
		var vizY:Float = 0;
		var vizFrames = Paths.getSparrowAtlas('abot/aBotViz');
		for (i in 1...VIZ_MAX+1)
		{
			volumes.push(0.0);
			vizX += VIZ_POS_X[i-1];
			vizY += VIZ_POS_Y[i-1];
			addVizBar(i, vizX, vizY, vizFrames, antialias);
		}

		eyeBg = new FlxSprite(-30, 215).makeGraphic(1, 1, FlxColor.WHITE);
		eyeBg.scale.set(160, 60);
		eyeBg.updateHitbox();
		add(eyeBg);

		#if flxanimate
		eyes = makeAnimate('abot/systemEyes', -10, 230, antialias);
		if (eyes != null)
		{
			eyes.anim.addBySymbolIndices('lookleft', 'a bot eyes lookin', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], 24, false);
			eyes.anim.addBySymbolIndices('lookright', 'a bot eyes lookin', [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35], 24, false);
			eyes.anim.play('lookright', true);
			eyes.anim.curFrame = eyes.anim.length - 1;
			add(eyes);
		}

		speaker = makeAnimate('abot/abotSystem', -65, -10, antialias);
		if (speaker != null)
		{
			speaker.anim.addBySymbol('anim', 'Abot System', 24, false);
			speaker.anim.play('anim', true);
			speaker.anim.curFrame = speaker.anim.length - 1;
			add(speaker);
		}
		#end
	}

	/**
	 * Creates one of the equalizer bars. Skipped (not crashed on) when the
	 * spritesheet or the `vizN` frames inside it are missing.
	 */
	function addVizBar(index:Int, posX:Float, posY:Float, vizFrames:FlxAtlasFrames, antialias:Bool):Void
	{
		if (vizFrames == null) return;

		final viz:FlxSprite = new FlxSprite(posX + 140, posY + 74);
		viz.frames = vizFrames;
		viz.animation.addByPrefix('VIZ', 'viz$index', 0);
		if (!viz.animation.exists('VIZ'))
		{
			// The sheet loaded but does not hold a `vizN` animation -- a
			// mismatched aBotViz atlas (wrong frame names/XML) is the other way
			// this used to end in a null `curAnim`.
			if (!vizAtlasWarned)
			{
				vizAtlasWarned = true;
				trace('ABotSpeaker: the abot/aBotViz atlas has no "vizN" frames, equalizer bars are off');
			}
			return;
		}

		viz.animation.play('VIZ', true);
		if (viz.animation.curAnim == null) return;

		viz.animation.curAnim.finish(); //make it go to the lowest point
		viz.antialiasing = antialias;
		vizSprites.push(viz);
		viz.updateHitbox();
		viz.centerOffsets();
		add(viz);
	}

	#if flxanimate
	/** Builds a FlxAnimate from an animate-atlas folder, or returns null when the art is unavailable. */
	function makeAnimate(asset:String, x:Float, y:Float, antialias:Bool):FlxAnimate
	{
		try
		{
			final animate = new FlxAnimate(x, y);
			Paths.loadAnimateAtlas(animate, asset);
			if (animate.anim == null) return null;
			animate.antialiasing = antialias;
			return animate;
		}
		catch (e:Dynamic)
		{
			trace('ABotSpeaker: animate atlas "$asset" is unavailable ($e)');
			return null;
		}
	}
	#end

	#if funkin.vis
	var levels:Array<Bar>;
	var levelMax:Int = 0;
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(analyzer == null) return;

		levels = analyzer.getLevels(levels);
		var oldLevelMax = levelMax;
		levelMax = 0;
		for (i in 0...Std.int(Math.min(vizSprites.length, levels.length)))
		{
			final anim = vizSprites[i].animation.curAnim;
			// No animation when the atlas frame was missing, so there is nothing
			// to drive -- the bar was skipped at creation time.
			if (anim == null) continue;

			var animFrame:Int = Math.round(levels[i].value * 5);
			animFrame = Std.int(Math.abs(FlxMath.bound(animFrame, 0, 5) - 5)); // awkward flip, because Dave's orientation is reversed.

			anim.curFrame = animFrame;
			levelMax = Std.int(Math.max(levelMax, 5 - animFrame));
		}

		if(levelMax >= 4)
		{
			//trace(levelMax);
			if(oldLevelMax <= levelMax && (levelMax >= 5 || #if flxanimate (speaker != null && speaker.anim != null && speaker.anim.curFrame >= 3) #else false #end))
				beatHit();
		}
	}
	#end

	public function beatHit()
	{
		#if flxanimate
		if (speaker != null && speaker.anim != null) speaker.anim.play('anim', true);
		#end
	}

	#if funkin.vis
	public function initAnalyzer()
	{
		analyzer = null;
		#if !flash
		// Nothing to drive when the viz atlas never loaded, and a stopped or
		// missing channel throws inside SpectralAnalyzer -- neither is worth
		// taking the song down over.
		if (snd == null || vizSprites.length == 0) return;
		try
		{
			@:privateAccess
			#if (openfl > "9.2.2")
			analyzer = new SpectralAnalyzer(snd._channel.__audioSource, 7, 0.1, 40);
			#else
			analyzer = new SpectralAnalyzer(snd._channel.__source, 7, 0.1, 40);
			#end

			#if desktop
			// On desktop it uses FFT stuff that isn't as optimized as the direct browser stuff we use on HTML5
			// So we want to manually change it!
			analyzer.fftN = 256;
			#end
		}
		catch (e:Dynamic)
		{
			analyzer = null;
			trace('ABotSpeaker: no spectrum analyzer for this track ($e)');
		}
		#end
	}
	#end

	var lookingAtRight:Bool = true;
	public function lookLeft()
	{
		#if flxanimate
		if(lookingAtRight && eyes != null && eyes.anim != null) eyes.anim.play('lookleft', true);
		#end
		lookingAtRight = false;
	}
	public function lookRight()
	{
		#if flxanimate
		if(!lookingAtRight && eyes != null && eyes.anim != null) eyes.anim.play('lookright', true);
		#end
		lookingAtRight = true;
	}
}