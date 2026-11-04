package shaders;

import objects.Note;
import backend.FlxFixedShader;

class RGBPalette {
	public var shader(default, null):RGBPaletteShader = new RGBPaletteShader();
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	// OpenFL re-reads the parameter array on every draw, so after the first
	// assignment these setters write into the existing array instead of
	// allocating a new [r, g, b] array per change (scripts can set these
	// every frame).
	private function set_r(color:FlxColor) {
		r = color;
		if (shader != null)
		{
			if (shader.r.value == null)
				shader.r.value = [color.redFloat, color.greenFloat, color.blueFloat];
			else
			{
				shader.r.value[0] = color.redFloat;
				shader.r.value[1] = color.greenFloat;
				shader.r.value[2] = color.blueFloat;
			}
		}
		return color;
	}

	private function set_g(color:FlxColor) {
		g = color;
		if (shader != null)
		{
			if (shader.g.value == null)
				shader.g.value = [color.redFloat, color.greenFloat, color.blueFloat];
			else
			{
				shader.g.value[0] = color.redFloat;
				shader.g.value[1] = color.greenFloat;
				shader.g.value[2] = color.blueFloat;
			}
		}
		return color;
	}

	private function set_b(color:FlxColor) {
		b = color;
		if (shader != null)
		{
			if (shader.b.value == null)
				shader.b.value = [color.redFloat, color.greenFloat, color.blueFloat];
			else
			{
				shader.b.value[0] = color.redFloat;
				shader.b.value[1] = color.greenFloat;
				shader.b.value[2] = color.blueFloat;
			}
		}
		return color;
	}

	private function set_mult(value:Float) {
		mult = FlxMath.bound(value, 0, 1);
		if (shader != null)
		{
			if (shader.mult.value == null)
				shader.mult.value = [mult];
			else
				shader.mult.value[0] = mult;
		}
		return mult;
	}

	public function new()
	{
		r = 0xFFFF0000;
		g = 0xFF00FF00;
		b = 0xFF0000FF;
		mult = 1.0;
	}
}

// automatic handler for easy usability
class RGBShaderReference
{
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;
	public var enabled(default, set):Bool = true;

	public var parent:RGBPalette;
	private var _owner:FlxSprite;
	private var _original:RGBPalette;
	public function new(owner:FlxSprite, ref:RGBPalette)
	{
		parent = ref;
		_owner = owner;
		_original = ref;
		owner.shader = ref.shader;

		@:bypassAccessor
		{
			r = parent.r;
			g = parent.g;
			b = parent.b;
			mult = parent.mult;
		}
	}

	private function set_r(value:FlxColor)
	{
		if(allowNew && value != _original.r) cloneOriginal();
		return (r = parent.r = value);
	}
	private function set_g(value:FlxColor)
	{
		if(allowNew && value != _original.g) cloneOriginal();
		return (g = parent.g = value);
	}
	private function set_b(value:FlxColor)
	{
		if(allowNew && value != _original.b) cloneOriginal();
		return (b = parent.b = value);
	}
	private function set_mult(value:Float)
	{
		if(allowNew && value != _original.mult) cloneOriginal();
		return (mult = parent.mult = value);
	}
	private function set_enabled(value:Bool)
	{
		_owner.shader = value ? parent.shader : null;
		return (enabled = value);
	}

	public var allowNew = true;
	private function cloneOriginal()
	{
		if(allowNew)
		{
			allowNew = false;
			if(_original != parent) return;

			parent = new RGBPalette();
			parent.r = _original.r;
			parent.g = _original.g;
			parent.b = _original.b;
			parent.mult = _original.mult;
			_owner.shader = parent.shader;
			//trace('created new shader');
		}
	}
}

class RGBPaletteShader extends FlxFixedShader {
	#if flash
	public var r:Dynamic = {};
	public var g:Dynamic = {};
	public var b:Dynamic = {};
	public var mult:Dynamic = {};
	#end

	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec4 color = flixel_texture2D(bitmap, coord);
			if (!hasTransform || color.a == 0.0 || mult == 0.0) {
				return color;
			}

			// Past the early return color.a is always > 0.0 (mix() below never
			// touched alpha either), so the old trailing
			// `if (color.a > 0.0) ... else return vec4(0.0)` could only take
			// the first branch; the vec4 copy through newColor is gone too.
			vec3 mapped = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			color.rgb = mix(color.rgb, mapped, mult);
			return color;
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}
