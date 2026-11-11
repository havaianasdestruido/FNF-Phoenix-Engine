package modchart;

/**
 * Pure 3D vector + rotation/projection math for the modchart runtime.
 *
 * Deliberately free of Flixel/OpenFL imports so the whole `modchart` core
 * (this file, the percent store, the event timeline, the playfield and every
 * modifier) can be exercised on the Haxe interpreter by
 * `tests/haxe/run-modchart.sh` without the game haxelibs. The runtime adapter
 * in `play.helpers.PlayStateModchart` is the only place that touches
 * `StrumNote`/`Note` sprites.
 */
class ModchartVec3
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var z:Float = 0;

	public function new(?x:Float = 0, ?y:Float = 0, ?z:Float = 0)
	{
		this.x = x;
		this.y = y;
		this.z = z;
	}

	public function set(?x:Float = 0, ?y:Float = 0, ?z:Float = 0):ModchartVec3
	{
		this.x = x;
		this.y = y;
		this.z = z;
		return this;
	}

	public function copyFrom(other:ModchartVec3):ModchartVec3
	{
		x = other.x;
		y = other.y;
		z = other.z;
		return this;
	}

	public function clone():ModchartVec3
	{
		return new ModchartVec3(x, y, z);
	}

	public function add(other:ModchartVec3):ModchartVec3
	{
		return new ModchartVec3(x + other.x, y + other.y, z + other.z);
	}

	public function subtract(other:ModchartVec3):ModchartVec3
	{
		return new ModchartVec3(x - other.x, y - other.y, z - other.z);
	}

	public function scaleBy(amount:Float):ModchartVec3
	{
		return new ModchartVec3(x * amount, y * amount, z * amount);
	}

	public function lerpTo(target:ModchartVec3, ratio:Float):ModchartVec3
	{
		return new ModchartVec3(lerp(x, target.x, ratio), lerp(y, target.y, ratio), lerp(z, target.z, ratio));
	}

	public static inline function lerp(a:Float, b:Float, ratio:Float):Float
	{
		return a + (b - a) * ratio;
	}

	public static inline function clamp(value:Float, min:Float, max:Float):Float
	{
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}

	public static inline function sign(value:Int):Int
	{
		return value == 0 ? 0 : (value > 0 ? 1 : -1);
	}

	/**
	 * Rotates `vec` around the X, Y and Z axes (degrees) in X-Y-Z order,
	 * matching FunkinModchart's default `Config.ROTATION_ORDER`.
	 */
	public static function rotate3D(vec:ModchartVec3, angleX:Float, angleY:Float, angleZ:Float):ModchartVec3
	{
		if (angleX == 0 && angleY == 0 && angleZ == 0)
			return vec;

		var out:ModchartVec3 = vec.clone();

		if (angleZ != 0)
		{
			final rad:Float = angleZ * Math.PI / 180;
			final cos:Float = Math.cos(rad);
			final sin:Float = Math.sin(rad);
			final nx:Float = out.x * cos - out.y * sin;
			final ny:Float = out.x * sin + out.y * cos;
			out.x = nx;
			out.y = ny;
		}
		if (angleY != 0)
		{
			final rad:Float = angleY * Math.PI / 180;
			final cos:Float = Math.cos(rad);
			final sin:Float = Math.sin(rad);
			final nx:Float = out.x * cos + out.z * sin;
			final nz:Float = -out.x * sin + out.z * cos;
			out.x = nx;
			out.z = nz;
		}
		if (angleX != 0)
		{
			final rad:Float = angleX * Math.PI / 180;
			final cos:Float = Math.cos(rad);
			final sin:Float = Math.sin(rad);
			final ny:Float = out.y * cos - out.z * sin;
			final nz:Float = out.y * sin + out.z * cos;
			out.y = ny;
			out.z = nz;
		}
		return out;
	}

	/**
	 * Perspective projection around `origin`, mirroring FunkinModchart's
	 * `View3D` with near=0/far=1/fov=90°. With `z == 0` this is the identity,
	 * so plain 2D modifiers are unaffected; pushing `z` scales `x`/`y`
	 * around the origin (screen centre by default).
	 */
	public static function project(vec:ModchartVec3, origin:ModchartVec3, fov:Float = 1.57079632679):ModchartVec3
	{
		final tanHalf:Float = Math.tan(fov * 0.5);
		final projectedZ:Float = Math.min(vec.z - 1, 0) * -1;
		if (projectedZ == 0)
			return vec.clone();
		final factor:Float = tanHalf / projectedZ;
		return new ModchartVec3(origin.x + (vec.x - origin.x) * factor, origin.y + (vec.y - origin.y) * factor, projectedZ);
	}
}
