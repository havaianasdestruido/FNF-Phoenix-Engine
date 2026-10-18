package shaders;

import backend.ClientPrefs;
import objects.Character;
import play.PlayState;

/**
 * Ghost sprite drawn behind a character when a cross fade note is hit.
 *
 * Instances are pooled (#88): the constructor takes no arguments so the
 * `PlayState.grp*CrossFade` groups can build them through
 * `FlxTypedGroup.recycle()`, every per-spawn assignment lives in `setup()`, and a
 * finished ghost is only `kill()`ed — it stays in its group as a dead member so
 * the next spawn revives it instead of allocating a new sprite, frames copy,
 * animation and fade callback.
 */
class CrossFade extends FlxSprite
{
	/** Fade-out callback, bound once per instance so `setup()` allocates no closure. */
	var fadeComplete:FlxTween->Void;

	public function new()
	{
		super();
		fadeComplete = onFadeComplete;
	}

	/**
	 * Prepares this pooled ghost for `character`.
	 *
	 * @param character the character whose current animation frame is copied.
	 * @param isDad     `true` on the opponent side of the strum line (drift direction).
	 * @return `false` when the effect must be skipped (the character already draws a
	 *         `FlxTrail`, or has no animation running); the caller then drops this
	 *         instance from its pool.
	 */
	public function setup(character:Character, ?isDad:Bool = true):Bool
	{
		if (character == null || character.flixelTrail) return false;
		if (character.animation == null || character.animation.curAnim == null) return false;

		// A recycled ghost can still be mid-fade from its previous life.
		FlxTween.cancelTweensOf(this);

		frames = character.frames;
		alpha = 0.3;
		setGraphicSize(Std.int(character.width), Std.int(character.height));
		scrollFactor.set(character.scrollFactor.x, character.scrollFactor.y);
		updateHitbox();
		flipX = character.flipX;
		flipY = character.flipY;
		velocity.y = 0;
		var curCrossFadeMode:String = ClientPrefs.crossFadeMode;
		switch (curCrossFadeMode)
		{
			case 'Mid-Fight Masses':
				x = character.x + FlxG.random.float(0, 60);
				y = character.y + FlxG.random.float(-50, 50);
			case 'Static':
				x = character.x + 60;
				y = character.y - 50;
			case 'Eccentric':
				x = character.x + FlxG.random.float(-20, 90);
				y = character.y + FlxG.random.float(-80, 80);
			default:
				x = character.x + FlxG.random.float(0, 60);
				y = character.y + FlxG.random.float(-50, 50);
		}
		offset.x = character.offset.x;
		offset.y = character.offset.y;
		animation.add('cur', character.animation.curAnim.frames, 24, false);
		animation.play('cur', true);
		animation.curAnim.curFrame = character.animation.curAnim.curFrame;
		switch (character.curCharacter)
		{
			case 'gf-pixel':
				color = 0xFFa5004d;
				antialiasing = false;
			case 'monster' | 'monster-christmas':
				color = 0xFF981b3a;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'pico' | 'pico-player':
				color = 0xff2c8c00;
				antialiasing = character.antialiasing;
			case 'bf' | 'bf-car' | 'bf-christmas':
				color = 0xFF1b008c;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'bf-holding-gf':
				color = FlxG.random.bool(50) ? 0xFF1b008c : 0xFFa5004d;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'parents-christmas':
				@:privateAccess
				var sectionIndex:Int = PlayState.instance.curSection;
				var isAlt:Bool = PlayState.SONG.notes[sectionIndex].altAnim;
				color = isAlt ? 0xff882952 : 0xff6a3381;
				antialiasing = character.antialiasing;
			case 'spooky':
				color = FlxG.random.bool(50) ? 0xff777777 : 0xff925500;
				antialiasing = character.antialiasing;
			case 'bf-pixel' | 'bf-pixel-opponent':
				color = 0xFF00368c;
				antialiasing = false;
			case 'senpai' | 'senpai-angry':
				color = 0xFFffaa6f;
				antialiasing = false;
			case 'tankman' | 'tankman-player':
				color = 0xff000000;
				antialiasing = ClientPrefs.globalAntialiasing;
			default:
				color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
				color = FlxColor.subtract(color, 0x00333333);
				antialiasing = ClientPrefs.globalAntialiasing;
		}

		var fuck = FlxG.random.bool(70);

		var velo = 12 * 5;
		switch (curCrossFadeMode)
		{
			case 'Mid-Fight Masses':
				if (isDad)
				{
					if (fuck)
						velocity.x = -velo;
					else
						velocity.x = velo;
				}
				else
				{
					if (fuck)
						velocity.x = velo;
					else
						velocity.x = -velo;
				}
			case 'Static':
				if (isDad)
				{
					if (fuck)
						velocity.x = 0;
					else
						velocity.x = 0;
				}
				else
				{
					if (fuck)
						velocity.x = 0;
					else
						velocity.x = 0;
				}
			case 'Eccentric':
				velo = 12 * 8;
				if (isDad)
				{
					if (fuck)
						velocity.x = -velo;
					else
						velocity.x = velo;
				}
				else
				{
					if (fuck)
						velocity.x = velo;
					else
						velocity.x = -velo;
				}
			default:
				if (isDad)
				{
					if (fuck)
						velocity.x = -velo;
					else
						velocity.x = velo;
				}
				else
				{
					if (fuck)
						velocity.x = velo;
					else
						velocity.x = -velo;
				}
		}

		FlxTween.tween(this, {alpha: 0}, 0.35, {onComplete: fadeComplete});

		return true;
	}

	/**
	 * Retires the ghost into its pool. It is deliberately not destroyed and not
	 * removed from the group: `recycle()` revives dead members, which is what keeps
	 * the pool warm for the rest of the song.
	 */
	function onFadeComplete(twn:FlxTween):Void
	{
		kill();
	}
}
