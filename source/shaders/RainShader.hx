package shaders;

import backend.FlxFixedShader;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import openfl.display.ShaderParameterType;

typedef Light =
{
	var position:Array<Float>;
	var color:Array<Float>;
	var radius:Float;
}

class RainShader extends FlxFixedShader
{
	@:glVertexHeader('
		  // normalized screen coord
		  //   (0, 0) is the top left of the window
		  //   (1, 1) is the bottom right of the window
		  varying vec2 screenCoord;
	  ', true)
	@:glVertexBody('
		  screenCoord = vec2(
			  openfl_TextureCoord.x > 0.0 ? 1.0 : 0.0,
			  openfl_TextureCoord.y > 0.0 ? 1.0 : 0.0
		  );
	  ')
	@:glFragmentHeader('
		  // normalized screen coord
		  //   (0, 0) is the top left of the window
		  //   (1, 1) is the bottom right of the window
		  varying vec2 screenCoord;

		  // equals (FlxG.width, FlxG.height)
		  uniform vec2 uScreenResolution;

		  // equals (camera.viewLeft, camera.viewTop, camera.viewRight, camera.viewBottom)
		  uniform vec4 uCameraBounds;

		  // screen coord -> world coord conversion
		  // returns world coord in px
		  vec2 screenToWorld(vec2 screenCoord) {
			  float left = uCameraBounds.x;
			  float top = uCameraBounds.y;
			  float right = uCameraBounds.z;
			  float bottom = uCameraBounds.w;
			  vec2 scale = vec2(right - left, bottom - top);
			  vec2 offset = vec2(left, top);
			  return screenCoord * scale + offset;
		  }

		  // world coord -> screen coord conversion
		  // returns normalized screen coord
		  vec2 worldToScreen(vec2 worldCoord) {
			  float left = uCameraBounds.x;
			  float top = uCameraBounds.y;
			  float right = uCameraBounds.z;
			  float bottom = uCameraBounds.w;
			  vec2 scale = vec2(right - left, bottom - top);
			  vec2 offset = vec2(left, top);
			  return (worldCoord - offset) / scale;
		  }

		  // internally used to get the maximum `openfl_TextureCoordv`
		  vec2 bitmapCoordScale() {
			  return openfl_TextureCoordv / screenCoord;
		  }

		  // internally used to compute bitmap coord
		  vec2 screenToBitmap(vec2 screenCoord) {
			  return screenCoord * bitmapCoordScale();
		  }

		  // samples the frame buffer using a screen coord
		  vec4 sampleBitmapScreen(vec2 screenCoord) {
			  return texture2D(bitmap, screenToBitmap(screenCoord));
		  }

		  // samples the frame buffer using a world coord
		  vec4 sampleBitmapWorld(vec2 worldCoord) {
			  return sampleBitmapScreen(worldToScreen(worldCoord));
		  }
	  ', true)

	@:glFragmentSource("
	  		#pragma header

			// The Ashima snoise block, puddle ripples (rippleHeight/
			// puddleDisplace) and light accumulation (ease/lightUp) that used
			// to live here were dead code: their only call sites were inside
			// commented-out GLSL. They were removed so drivers no longer
			// compile ~200 unused lines (incl. a 30-iteration loop) into this
			// program on every stage load. The Light struct, lights[] and the
			// uPuddle*/uMask/uBlurredScreen/uLightMap uniforms stay declared
			// because the Haxe side still exposes setters for them.

			struct Light {
				vec2 position;
				vec3 color;
				float radius;
			};

			// prevent auto field generation
			#define UNIFORM uniform

			uniform float uScale;
			uniform float uIntensity;
			uniform float uTime;
			uniform float uPuddleY;
			uniform float uPuddleScaleY;
			uniform sampler2D uBlurredScreen;
			uniform sampler2D uMask;
			uniform sampler2D uLightMap;
			uniform int numLights;

			const int MAX_LIGHTS = 8;
			UNIFORM Light lights[MAX_LIGHTS];

			float rand(vec2 a) {
				return fract(sin(dot(mod(a, vec2(1000.0)).xy, vec2(12.9898, 78.233))) * 43758.5453);
			}

			float rainDist(vec2 p, float scale, float intensity) {
				// scale everything
				p *= 0.1;
				// sheer
				p.x += p.y * 0.1;
				// scroll
				p.y -= uTime * 500.0 / scale;
				// expand Y
				p.y *= 0.03;
				float ix = floor(p.x);
				// shift Y
				p.y += mod(ix, 2.0) * 0.5 + (rand(vec2(ix)) - 0.5) * 0.3;
				float iy = floor(p.y);
				vec2 index = vec2(ix, iy);
				// mod
				p -= index;
				// shift X
				p.x += (rand(index.yx) * 2.0 - 1.0) * 0.35;
				// distance
				vec2 a = abs(p - 0.5);
				float res = max(a.x * 0.8, a.y * 0.5) - 0.1;
				// decimate
				bool empty = rand(index) < mix(1.0, 0.1, intensity);
				return empty ? 1.0 : res;
			}
			void main() {
				vec2 wpos = screenToWorld(screenCoord);

				// With no rain every layer takes the `empty` branch of
				// rainDist(), rainSum stays 0 and the output is the plain
				// sample. Skip the four rainDist() evaluations entirely.
				if (uIntensity <= 0.0) {
					gl_FragColor = vec4(sampleBitmapWorld(wpos).xyz, 1);
					return;
				}

				float intensity = uIntensity;

				vec3 add = vec3(0);
				float rainSum = 0.0;

				const int numLayers = 4;
				float scales[4];
				scales[0] = 1.0;
				scales[1] = 1.8;
				scales[2] = 2.6;
				scales[3] = 4.8;

				for (int i = 0; i < numLayers; i++) {
					float scale = scales[i];
					float r = rainDist(wpos * scale / uScale + 500.0 * float(i), scale, intensity);
					if (r < 0.0) {
						float v = (1.0 - exp(r * 5.0)) / scale * 2.0;
						wpos.x += v * 10.0 * uScale;
						wpos.y -= v * 2.0 * uScale;
						add += vec3(0.1, 0.15, 0.2) * v;
						rainSum += (1.0 - rainSum) * 0.75;
					}
				}

				vec3 color = sampleBitmapWorld(wpos).xyz;
				vec3 rainColor = vec3(0.4, 0.5, 0.8);
				color += add;
				color = mix(color, rainColor, 0.1 * rainSum);
				gl_FragColor = vec4(color, 1);
			}
		")

	static final MAX_LIGHTS:Int = 8;

	public var lights:Array<
	{
		position:ShaderParameter<Float>,
		color:ShaderParameter<Float>,
		radius:ShaderParameter<Float>,
	}>;

	public var time(default, set):Float = 1;

	function set_time(value:Float):Float
	{
		#if !flash
		this.uTime.value[0] = value;
		#end
		return time = value;
	}

	// The scale of the rain depends on the world coordinate system, so higher resolution makes
	// the raindrops smaller. This parameter can be used to adjust the total scale of the scene.
	// The size of the raindrops is proportional to the value of this parameter.
	public var scale(default, set):Float = 1;

	function set_scale(value:Float):Float
	{
		#if !flash
		this.uScale.value[0] = value;
		#end
		return scale = value;
	}

	// The intensity of the rain. Zero means no rain and one means the maximum amount of rain.
	public var intensity(default, set):Float = 0.5;

	function set_intensity(value:Float):Float
	{
		#if !flash
		this.uIntensity.value[0] = value;
		#end
		return intensity = value;
	}

	// the y coord of the puddle, used to mirror things
	public var puddleY(default, set):Float = 0;

	function set_puddleY(value:Float):Float
	{
		#if !flash
		this.uPuddleY.value[0] = value;
		#end
		return puddleY = value;
	}

	// the y scale of the puddle, the less this value the more the puddle effects squished
	public var puddleScaleY(default, set):Float = 0;

	function set_puddleScaleY(value:Float):Float
	{
		#if !flash
		this.uPuddleScaleY.value[0] = value;
		#end
		return puddleScaleY = value;
	}

	public var blurredScreen(default, set):BitmapData;

	function set_blurredScreen(value:BitmapData):BitmapData
	{
		#if !flash
		this.uBlurredScreen.input = value;
		#end
		return blurredScreen = value;
	}

	public var mask(default, set):BitmapData;

	function set_mask(value:BitmapData):BitmapData
	{
		#if !flash
		this.uMask.input = value;
		#end
		return mask = value;
	}

	public var lightMap(default, set):BitmapData;

	function set_lightMap(value:BitmapData):BitmapData
	{
		#if !flash
		this.uLightMap.input = value;
		#end
		return lightMap = value;
	}

	public var numLightsSwag(default, set):Int = 0; // swag heads, we have never been more back (needs different name purely for hashlink casting fix)

	function set_numLightsSwag(value:Int):Int
	{
		#if !flash
		this.numLights.value[0] = value;
		#end
		return numLightsSwag = value;
	}

	public function new()
	{
		super();
		#if !flash
		this.uTime.value = [1.0];
		this.uScale.value = [1.0];
		this.uIntensity.value = [0.5];
		this.uPuddleY.value = [0.0];
		this.uPuddleScaleY.value = [0.0];
		this.numLights.value = [0];
		this.uScreenResolution.value = [FlxG.width, FlxG.height];
		#end
	}

	public function update(elapsed:Float):Void
	{
		time += elapsed;
	}

	/*override function __processGLData(source:String, storageType:String):Void
	{
		super.__processGLData(source, storageType);
		if (storageType == 'uniform')
		{
			lights = [
				for (i in 0...MAX_LIGHTS)
				{
					position: addFloatUniform('lights[$i].position', 2),
					color: addFloatUniform('lights[$i].color', 3),
					radius: addFloatUniform('lights[$i].radius', 1),
				}
			];
		}
	}*/

	var _size:Array<Float> = [0, 0];
	var _view:Array<Float> = [0, 0, 0, 0];

	public function updateViewInfo(screenWidth:Float, screenHeight:Float, camera:FlxCamera):Void
	{
		_size[0] = screenWidth;
		_size[1] = screenHeight;
		#if !flash
		uScreenResolution.value = _size;
		#end

		_view[0] = camera.viewLeft;
		_view[1] = camera.viewTop;
		_view[2] = camera.viewRight;
		_view[3] = camera.viewBottom;
		#if !flash
		uCameraBounds.value = _view;
		#end
	}

	/*override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
	  try
	  {
		final res = super.__createGLProgram(vertexSource, fragmentSource);
		return res;
	  }
	  catch (error)
	  {
		Log.warn(error); // prevent the app from dying immediately
		return null;
	  }
	}*/

	#if !flash
	@:access(openfl.display.ShaderParameter)
	function addFloatUniform(name:String, length:Int):ShaderParameter<Float>
	{
		final res = new ShaderParameter<Float>();
		res.name = name;
		res.type = [null, FLOAT, FLOAT2, FLOAT3, FLOAT4][length];
		res.__arrayLength = 1;
		res.__isFloat = true;
		res.__isUniform = true;
		res.__length = length;
		__paramFloat.push(res);
		return res;
	}
	#end
}
