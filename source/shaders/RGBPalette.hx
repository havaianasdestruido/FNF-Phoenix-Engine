package shaders;

import objects.Note;
import backend.FlxFixedShader;

class RGBPalette {
	public var shader(default, null):RGBPaletteShader = new RGBPaletteShader();
	public var r(default, set):FlxColor;
	public var g(default, set):FlxColor;
	public var b(default, set):FlxColor;
	public var mult(default, set):Float;

	/**
	 * Executes the `set_r` operation.
	 * @param color Input value for `color`.
	 * @return Result produced by `set_r`, when applicable.
	 */
	private function set_r(color:FlxColor) {
		r = color;
		if (shader != null)
			shader.r.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	/**
	 * Executes the `set_g` operation.
	 * @param color Input value for `color`.
	 * @return Result produced by `set_g`, when applicable.
	 */
	private function set_g(color:FlxColor) {
		g = color;
		if (shader != null)
			shader.g.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	/**
	 * Executes the `set_b` operation.
	 * @param color Input value for `color`.
	 * @return Result produced by `set_b`, when applicable.
	 */
	private function set_b(color:FlxColor) {
		b = color;
		if (shader != null)
			shader.b.value = [color.redFloat, color.greenFloat, color.blueFloat];
		return color;
	}

	/**
	 * Executes the `set_mult` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_mult`, when applicable.
	 */
	private function set_mult(value:Float) {
		mult = FlxMath.bound(value, 0, 1);
		if (shader != null)
			shader.mult.value = [mult];
		return mult;
	}

	/**
	 * Executes the `new` operation.
	 */
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
	/**
	 * Executes the `new` operation.
	 * @param owner Input value for `owner`.
	 * @param ref Input value for `ref`.
	 */
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

	/**
	 * Executes the `set_r` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_r`, when applicable.
	 */
	private function set_r(value:FlxColor)
	{
		if(allowNew && value != _original.r) cloneOriginal();
		return (r = parent.r = value);
	}
	/**
	 * Executes the `set_g` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_g`, when applicable.
	 */
	private function set_g(value:FlxColor)
	{
		if(allowNew && value != _original.g) cloneOriginal();
		return (g = parent.g = value);
	}
	/**
	 * Executes the `set_b` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_b`, when applicable.
	 */
	private function set_b(value:FlxColor)
	{
		if(allowNew && value != _original.b) cloneOriginal();
		return (b = parent.b = value);
	}
	/**
	 * Executes the `set_mult` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_mult`, when applicable.
	 */
	private function set_mult(value:Float)
	{
		if(allowNew && value != _original.mult) cloneOriginal();
		return (mult = parent.mult = value);
	}
	/**
	 * Executes the `set_enabled` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_enabled`, when applicable.
	 */
	private function set_enabled(value:Bool)
	{
		_owner.shader = value ? parent.shader : null;
		return (enabled = value);
	}

	public var allowNew = true;
	/**
	 * Executes the `cloneOriginal` operation.
	 * @return Result produced by `cloneOriginal`, when applicable.
	 */
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

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;

			color = mix(color, newColor, mult);

			if(color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	/**
	 * Executes the `new` operation.
	 */
	public function new()
	{
		super();
	}
}
