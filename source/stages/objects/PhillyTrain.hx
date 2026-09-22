package stages.objects;
import backend.ClientPrefs;
import backend.Paths;
import objects.BGSprite;
import play.PlayState;

class PhillyTrain extends BGSprite
{
	public var sound:FlxSound;
	/**
	 * Executes the `new` operation.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @param image Input value for `image`.
	 * @param sound Input value for `sound`.
	 */
	public function new(x:Float = 0, y:Float = 0, image:String = 'philly/train', sound:String = 'train_passes')
	{
		super(image, x, y);
		active = true; //Allow update
		antialiasing = ClientPrefs.globalAntialiasing;

		this.sound = new FlxSound().loadEmbedded(Paths.sound(sound));
		FlxG.sound.list.add(this.sound);
	}

	public var moving:Bool = false;
	public var finishing:Bool = false;
	public var startedMoving:Bool = false;
	public var frameTiming:Float = 0; //Simulates 24fps cap

	public var cars:Int = 8;
	public var cooldown:Int = 0;

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		if (moving)
		{
			frameTiming += elapsed;
			if (frameTiming >= 1 / 24)
			{
				if (sound.time >= 4700)
				{
					startedMoving = true;
					if (PlayState.instance.gf != null)
					{
						PlayState.instance.gf.playAnim('hairBlow');
						PlayState.instance.gf.specialAnim = true;
					}
				}
		
				if (startedMoving)
				{
					x -= 400;
					if (x < -2000 && !finishing)
					{
						x = -1150;
						cars -= 1;

						if (cars <= 0)
							finishing = true;
					}

					if (x < -4000 && finishing)
						restart();
				}
				frameTiming = 0;
			}
		}
		super.update(elapsed);
	}

	/**
	 * Executes the `beatHit` operation.
	 * @param curBeat Input value for `curBeat`.
	 */
	public function beatHit(curBeat:Int):Void
	{
		if (!moving)
			cooldown += 1;

		if (curBeat % 8 == 4 && FlxG.random.bool(30) && !moving && cooldown > 8)
		{
			cooldown = FlxG.random.int(-4, 0);
			start();
		}
	}
	
	/**
	 * Executes the `start` operation.
	 */
	public function start():Void
	{
		moving = true;
		if (!sound.playing)
			sound.play(true);
	}

	/**
	 * Executes the `restart` operation.
	 */
	public function restart():Void
	{
		if(PlayState.instance.gf != null)
		{
			PlayState.instance.gf.danced = false; //Makes she bop her head to the correct side once the animation ends
			PlayState.instance.gf.playAnim('hairFall');
			PlayState.instance.gf.specialAnim = true;
		}
		x = FlxG.width + 200;
		moving = false;
		cars = 8;
		finishing = false;
		startedMoving = false;
	}
}