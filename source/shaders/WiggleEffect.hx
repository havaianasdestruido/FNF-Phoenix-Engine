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

	public function new(typeOfEffect:WiggleEffectType = DREAMY, waveSpeed:Float = 0, waveFrequency:Float = 0, waveAmplitude:Float = 0):Void
	{
		shader.uTime.value = [0];
		this.waveSpeed = waveSpeed;
		this.waveFrequency = waveFrequency;
		this.waveAmplitude = waveAmplitude;
		// Was `this.effectType = effectType`, which re-assigned the field's
		// own DREAMY default and silently ignored the typeOfEffect argument.
		this.effectType = typeOfEffect;
	}

	public function update(elapsed:Float):Void
	{
		shader.uTime.value[0] += elapsed;
	}

	public function setValue(value:Float):Void
	{
		shader.uTime.value[0] = value;
	}

	// Type.enumIndex() is the same declaration-order index the old
	// getConstructors().indexOf(Std.string(v)) computed through reflection
	// (which also allocated the constructor array and a String per call).
	// The float setters likewise write into the existing uniform array
	// after the first assignment instead of allocating [v] every time.
	function set_effectType(v:WiggleEffectType):WiggleEffectType
	{
		effectType = v;
		if (shader.effectType.value == null)
			shader.effectType.value = [Type.enumIndex(v)];
		else
			shader.effectType.value[0] = Type.enumIndex(v);
		return v;
	}

	function set_waveSpeed(v:Float):Float
	{
		waveSpeed = v;
		if (shader.uSpeed.value == null)
			shader.uSpeed.value = [waveSpeed];
		else
			shader.uSpeed.value[0] = waveSpeed;
		return v;
	}

	function set_waveFrequency(v:Float):Float
	{
		waveFrequency = v;
		if (shader.uFrequency.value == null)
			shader.uFrequency.value = [waveFrequency];
		else
			shader.uFrequency.value[0] = waveFrequency;
		return v;
	}

	function set_waveAmplitude(v:Float):Float
	{
		waveAmplitude = v;
		if (shader.uWaveAmplitude.value == null)
			shader.uWaveAmplitude.value = [waveAmplitude];
		else
			shader.uWaveAmplitude.value[0] = waveAmplitude;
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
			// Every effect type scales its offset by uWaveAmplitude, so at
			// zero amplitude sineWave() returns the coord unchanged. Skip
			// the sin() calls entirely in that (common, disabled) state.
			vec2 uv = openfl_TextureCoordv;
			if (uWaveAmplitude != 0.0)
				uv = sineWave(uv);
			gl_FragColor = texture2D(bitmap, uv);
		}')
	public function new()
	{
		super();
	}
}
