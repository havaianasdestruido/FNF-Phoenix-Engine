package objects;

import backend.FlxFixedShader;

class ColorSwap {
	public var shader(default, null):ColorSwapShader = new ColorSwapShader();
	public var hue(default, set):Float = 0;
	public var saturation(default, set):Float = 0;
	public var brightness(default, set):Float = 0;

	private function set_hue(value:Float) {
		hue = value;
		shader.uTime.value[0] = hue;
		return hue;
	}

	private function set_saturation(value:Float) {
		saturation = value;
		shader.uTime.value[1] = saturation;
		return saturation;
	}

	private function set_brightness(value:Float) {
		brightness = value;
		shader.uTime.value[2] = brightness;
		return brightness;
	}

	public function new()
	{
		shader.uTime.value = [0, 0, 0];
		shader.awesomeOutline.value = [false];
	}
}

class ColorSwapShader extends FlxFixedShader {
	#if flash
	public var uTime:Dynamic = {};
	public var awesomeOutline:Dynamic = {};
	public var y:Dynamic = {};
	public var passes:Dynamic = {};
	#end

	@:glFragmentSource('
		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;
		uniform sampler2D bitmap;

		uniform bool hasTransform;
		uniform bool hasColorTransform;
    		uniform bool blurEnabled;
    		uniform int passes;
       		uniform float x;
        	uniform float y;
       		uniform bool isNote;

		vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
		{
			vec4 color = texture2D(bitmap, coord);
			if (!hasTransform)
			{
				return color;
			}

			if (color.a == 0.0)
			{
				return vec4(0.0, 0.0, 0.0, 0.0);
			}

			if (!hasColorTransform)
			{
				return color * openfl_Alphav;
			}

			color = vec4(color.rgb / color.a, color.a);

			// The color multiplier was applied by building a diagonal mat4 on
			// every call; a component-wise multiply by the same diagonal
			// (v * diag(m) == v * m) gives identical results for one op.
			color = clamp(openfl_ColorOffsetv + (color * openfl_ColorMultiplierv), 0.0, 1.0);

			if (color.a > 0.0)
			{
				return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}

		uniform vec3 uTime;
		uniform bool awesomeOutline;

		const float offset = 1.0 / 128.0;

		vec3 rgb2hsv(vec3 c)
		{
			vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
			vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}

		vec3 hsv2rgb(vec3 c)
		{
			vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			// Most sprites using this shader never change hue/saturation/
			// brightness (uTime stays at its 0,0,0 default), but every pixel
			// still paid for a full RGB->HSV->RGB round-trip that only
			// reproduces the input. Skip it when there is nothing to swap
			// and no outline to draw; the branch is uniform-coherent.
			if (!awesomeOutline && uTime == vec3(0.0))
			{
				gl_FragColor = color;
				return;
			}

			// uTime is (hue, saturation, brightness) despite the name.
			vec3 hsv = rgb2hsv(color.rgb);
			hsv.x += uTime.x;
			hsv.y = clamp(hsv.y + uTime.y, 0.0, 1.0);
			hsv.z *= (1.0 + uTime.z);

			color = vec4(hsv2rgb(hsv), color.a);

			if (awesomeOutline)
			{
				 // Outline bullshit?
				vec2 size = vec2(3, 3);

				if (color.a <= 0.5) {
					float w = size.x / openfl_TextureSize.x;
					float h = size.y / openfl_TextureSize.y;

					if (flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x + w, openfl_TextureCoordv.y)).a != 0.
					|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x - w, openfl_TextureCoordv.y)).a != 0.
					|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y + h)).a != 0.
					|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y - h)).a != 0.)
						color = vec4(1.0, 1.0, 1.0, 1.0);
				}
			}
			gl_FragColor = color;

			/*
			if (color.a > 0.5)
				gl_FragColor = color;
			else
			{
				float a = flixel_texture2D(bitmap, vec2(openfl_TextureCoordv + offset, openfl_TextureCoordv.y)).a +
						  flixel_texture2D(bitmap, vec2(openfl_TextureCoordv, openfl_TextureCoordv.y - offset)).a +
						  flixel_texture2D(bitmap, vec2(openfl_TextureCoordv - offset, openfl_TextureCoordv.y)).a +
						  flixel_texture2D(bitmap, vec2(openfl_TextureCoordv, openfl_TextureCoordv.y + offset)).a;
				if (color.a < 1.0 && a > 0.0)
					gl_FragColor = vec4(0.0, 0.0, 0.0, 0.8);
				else
					gl_FragColor = color;
			} */
		}')
	@:glVertexSource('
		attribute float openfl_Alpha;
		attribute vec4 openfl_ColorMultiplier;
		attribute vec4 openfl_ColorOffset;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;

		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform mat4 openfl_Matrix;
		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;

		attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;

		void main(void)
		{
			openfl_Alphav = openfl_Alpha;
			openfl_TextureCoordv = openfl_TextureCoord;

			if (openfl_HasColorTransform) {
				openfl_ColorMultiplierv = openfl_ColorMultiplier;
				openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
			}

			gl_Position = openfl_Matrix * openfl_Position;

			openfl_Alphav = openfl_Alpha * alpha;
			if (hasColorTransform)
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}
		}')

	public function new()
	{
		super();
        	this.y.value = [0.0075];
		this.passes.value = [10];
	}
}
