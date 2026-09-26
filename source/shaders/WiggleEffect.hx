package shaders;

// STOLEN FROM HAXEFLIXEL DEMO LOL
import backend.FlxFixedShader;

enum WiggleEffectType
{
	DREAMY;
	WAVY;
	HEAT_WAVE_HORIZONTAL;
	HEAT_WAVE_VERTICAL;
	FLAG;
	HEAT_WAVE_BOTH;
}

class WiggleEffect
{
	public var shader(default, null):WiggleShader = new WiggleShader();
	public var effectType(default, set):WiggleEffectType = DREAMY;
	public var waveSpeed(default, set):Float = 0;
	public var waveFrequency(default, set):Float = 0;
	public var waveAmplitude(default, set):Float = 0;

	/**
	 * Executes the `new` operation.
	 * @param typeOfEffect Input value for `typeOfEffect`.
	 * @param waveSpeed Input value for `waveSpeed`.
	 * @param waveFrequency Input value for `waveFrequency`.
	 * @param waveAmplitude Input value for `waveAmplitude`.
	 */
	public function new(typeOfEffect:WiggleEffectType = DREAMY, waveSpeed:Float = 0, waveFrequency:Float = 0, waveAmplitude:Float = 0):Void
	{
		shader.uTime.value = [0];
		this.waveSpeed = waveSpeed;
		this.waveFrequency = waveFrequency;
		this.waveAmplitude = waveAmplitude;
		this.effectType = effectType;
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 */
	public function update(elapsed:Float):Void
	{
		shader.uTime.value[0] += elapsed;
	}

	/**
	 * Executes the `setValue` operation.
	 * @param value Input value for `value`.
	 */
	public function setValue(value:Float):Void
	{
		shader.uTime.value[0] = value;
	}

	/**
	 * Executes the `set_effectType` operation.
	 * @param v Input value for `v`.
	 * @return Result produced by `set_effectType`, when applicable.
	 */
	function set_effectType(v:WiggleEffectType):WiggleEffectType
	{
		effectType = v;
		shader.effectType.value = [WiggleEffectType.getConstructors().indexOf(Std.string(v))];
		return v;
	}

	/**
	 * Executes the `set_waveSpeed` operation.
	 * @param v Input value for `v`.
	 * @return Result produced by `set_waveSpeed`, when applicable.
	 */
	function set_waveSpeed(v:Float):Float
	{
		waveSpeed = v;
		shader.uSpeed.value = [waveSpeed];
		return v;
	}

	/**
	 * Executes the `set_waveFrequency` operation.
	 * @param v Input value for `v`.
	 * @return Result produced by `set_waveFrequency`, when applicable.
	 */
	function set_waveFrequency(v:Float):Float
	{
		waveFrequency = v;
		shader.uFrequency.value = [waveFrequency];
		return v;
	}

	/**
	 * Executes the `set_waveAmplitude` operation.
	 * @param v Input value for `v`.
	 * @return Result produced by `set_waveAmplitude`, when applicable.
	 */
	function set_waveAmplitude(v:Float):Float
	{
		waveAmplitude = v;
		shader.uWaveAmplitude.value = [waveAmplitude];
		return v;
	}
}

class WiggleShader extends FlxFixedShader
{
	@:glFragmentSource('
		#pragma header
		//uniform float tx, ty; // x,y waves phase
		uniform float uTime;

		const int EFFECT_TYPE_DREAMY = 0;
		const int EFFECT_TYPE_WAVY = 1;
		const int EFFECT_TYPE_HEAT_WAVE_HORIZONTAL = 2;
		const int EFFECT_TYPE_HEAT_WAVE_VERTICAL = 3;
		const int EFFECT_TYPE_FLAG = 4;
		const int EFFECT_TYPE_HEAT_WAVE_BOTH = 5;

		uniform int effectType;

		/**
		 * How fast the waves move over time
		 */
		uniform float uSpeed;

		/**
		 * Number of waves over time
		 */
		uniform float uFrequency;

		/**
		 * How much the pixels are going to stretch over the waves
		 */
		uniform float uWaveAmplitude;

		uniform float verticalStrength;
		uniform float horizontalStrength;

		vec2 sineWave(vec2 pt)
		{
			float x = 0.0;
			float y = 0.0;

			if (effectType == EFFECT_TYPE_DREAMY)
			{
				float offsetX = sin(pt.y * uFrequency + uTime * uSpeed) * uWaveAmplitude;
                pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
			}
			else if (effectType == EFFECT_TYPE_WAVY)
			{
				float offsetY = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
				pt.y += offsetY; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
			}
			else if (effectType == EFFECT_TYPE_HEAT_WAVE_HORIZONTAL)
			{
				x = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
			}
			else if (effectType == EFFECT_TYPE_HEAT_WAVE_VERTICAL)
			{
				y = sin(pt.y * uFrequency + uTime * uSpeed) * uWaveAmplitude;
			}
			else if (effectType == EFFECT_TYPE_FLAG)
			{
				y = sin(pt.y * uFrequency + 10.0 * pt.x + uTime * uSpeed) * uWaveAmplitude;
				x = sin(pt.x * uFrequency + 5.0 * pt.y + uTime * uSpeed) * uWaveAmplitude;
			}
			else if (effectType == EFFECT_TYPE_HEAT_WAVE_BOTH)
			{
				x = sin(pt.x * (uFrequency * horizontalStrength) + uTime * (uSpeed * horizontalStrength)) * (uWaveAmplitude * horizontalStrength);
				y = sin(pt.y * (uFrequency * verticalStrength) + uTime * (uSpeed * verticalStrength)) * (uWaveAmplitude * verticalStrength);
			}

			return vec2(pt.x + x, pt.y + y);
		}

		void main()
		{
			vec2 uv = sineWave(openfl_TextureCoordv);
			gl_FragColor = texture2D(bitmap, uv);
		}')
	/**
	 * Executes the `new` operation.
*/
	public function new()
	{
		super();
	}
}
