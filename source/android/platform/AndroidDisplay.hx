/*
 * Copyright (C) 2026 Phoenix Engine Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package android.platform;

import flixel.util.FlxSignal;
import haxe.Json;
#if android
import lime.system.JNI;
#end

/**
 * Native display information: physical resolution, density/DPI, orientation,
 * refresh rate and display cutout insets, plus immersive (edge-to-edge)
 * fullscreen handling.
 */
class AndroidDisplay
{
	// android.view.Surface rotation constants.
	public static inline final ROTATION_0:Int = 0;
	public static inline final ROTATION_90:Int = 1;
	public static inline final ROTATION_180:Int = 2;
	public static inline final ROTATION_270:Int = 3;

	/** Fired when the display configuration changes (rotation, mode, ...). */
	public static var onChanged(get, never):FlxSignal;

	static inline function get_onChanged():FlxSignal
		return AndroidBridge.onDisplayChanged;

	// ------------------------------------------------------------------
	// Display information
	// ------------------------------------------------------------------

	/**
	 * Queries the display for full information. On non-Android targets
	 * returns null; callers should fall back to FlxG.stage dimensions.
	 */
	public static function getInfo():Null<DisplayInfo>
	{
		#if android
		var raw:String = getDisplayInfo_jni();
		if (raw == null || raw.length == 0)
			return null;

		try
		{
			var data:Dynamic = Json.parse(raw);
			var rates:Array<Float> = [];
			if (data.supportedRefreshRates != null)
			{
				for (rate in (data.supportedRefreshRates : Array<Dynamic>))
					rates.push(Std.parseFloat(Std.string(rate)));
			}

			var cutout = [0, 0, 0, 0];
			if (data.cutout != null)
			{
				var values:Array<Dynamic> = cast data.cutout;
				for (i in 0...4)
					cutout[i] = Std.parseInt(Std.string(values[i])) ?? 0;
			}

			return {
				width: Std.parseInt(Std.string(data.width)) ?? 0,
				height: Std.parseInt(Std.string(data.height)) ?? 0,
				densityDpi: Std.parseInt(Std.string(data.densityDpi)) ?? 0,
				xdpi: Std.parseFloat(Std.string(data.xdpi)),
				ydpi: Std.parseFloat(Std.string(data.ydpi)),
				rotation: Std.parseInt(Std.string(data.rotation)) ?? 0,
				refreshRate: Std.parseFloat(Std.string(data.refreshRate)),
				supportedRefreshRates: rates,
				cutout: cutout
			};
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	/** Cutout safe insets as {left, top, right, bottom} pixels (all 0 when none). */
	public static function getCutoutInsets():CutoutInsets
	{
		#if android
		var raw:String = getCutoutInsets_jni();
		var parts = (raw ?? "0,0,0,0").split(',');
		return {
			left: Std.parseInt(parts[0]) ?? 0,
			top: Std.parseInt(parts[1]) ?? 0,
			right: Std.parseInt(parts[2]) ?? 0,
			bottom: Std.parseInt(parts[3]) ?? 0
		};
		#else
		return {left: 0, top: 0, right: 0, bottom: 0};
		#end
	}

	/** Active display refresh rate (falls back to 60 when unknown). */
	public static function getRefreshRate():Float
	{
		var info = getInfo();
		if (info == null || !Math.isFinite(info.refreshRate) || info.refreshRate <= 0)
			return 60;
		return info.refreshRate;
	}

	// ------------------------------------------------------------------
	// Immersive / edge-to-edge
	// ------------------------------------------------------------------

	/**
	 * Applies an immersive mode:
	 *   "full" - hide status + navigation bars, re-show transiently on swipe
	 *   "lean" - hide bars, any swipe re-shows them
	 *   "off"  - restore all system bars
	 */
	public static function setImmersive(mode:String = "full"):Void
	{
		#if android
		setImmersive_jni(mode);
		#end
	}

	/**
	 * Display cutout behavior: "default", "shortEdges", "always" or "never".
	 * Controls how content lays out around notches and hole-punch cameras.
	 */
	public static function setCutoutMode(mode:String = "shortEdges"):Void
	{
		#if android
		setCutoutMode_jni(mode);
		#end
	}

	/**
	 * Best-effort request for a preferred refresh rate (API 23+). Pass 0 to
	 * clear the preference.
	 */
	public static function setPreferredRefreshRate(rate:Float):Void
	{
		#if android
		setPreferredRefreshRate_jni(rate);
		#end
	}

	/** Starts receiving display change events (`onChanged`). */
	public static function watchDisplay():Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		registerDisplayListener_jni();
		#end
	}

	// ------------------------------------------------------------------
	// JNI bindings
	// ------------------------------------------------------------------

	#if android
	static var _getDisplayInfo:Dynamic = null;

	static function getDisplayInfo_jni():String
	{
		if (_getDisplayInfo == null)
			_getDisplayInfo = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'getDisplayInfo', '()Ljava/lang/String;');
		return _getDisplayInfo();
	}

	static var _getCutoutInsets:Dynamic = null;

	static function getCutoutInsets_jni():String
	{
		if (_getCutoutInsets == null)
			_getCutoutInsets = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'getCutoutInsets', '()Ljava/lang/String;');
		return _getCutoutInsets();
	}

	static var _setImmersive:Dynamic = null;

	static function setImmersive_jni(mode:String):Void
	{
		if (_setImmersive == null)
			_setImmersive = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'setImmersive', '(Ljava/lang/String;)V');
		_setImmersive(mode);
	}

	static var _setCutoutMode:Dynamic = null;

	static function setCutoutMode_jni(mode:String):Void
	{
		if (_setCutoutMode == null)
			_setCutoutMode = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'setCutoutMode', '(Ljava/lang/String;)V');
		_setCutoutMode(mode);
	}

	static var _setPreferredRefreshRate:Dynamic = null;

	static function setPreferredRefreshRate_jni(rate:Float):Void
	{
		if (_setPreferredRefreshRate == null)
			_setPreferredRefreshRate = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'setPreferredRefreshRate', '(F)V');
		_setPreferredRefreshRate(rate);
	}

	static var _registerDisplayListener:Dynamic = null;

	static function registerDisplayListener_jni():Void
	{
		if (_registerDisplayListener == null)
			_registerDisplayListener = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixDisplay', 'registerDisplayListener', '()V');
		_registerDisplayListener();
	}
	#end
}

typedef DisplayInfo =
{
	var width:Int;
	var height:Int;
	var densityDpi:Int;
	var xdpi:Float;
	var ydpi:Float;
	/** android.view.Surface rotation constant. */
	var rotation:Int;
	var refreshRate:Float;
	var supportedRefreshRates:Array<Float>;
	/** Cutout safe insets: [left, top, right, bottom]. */
	var cutout:Array<Int>;
}

typedef CutoutInsets =
{
	var left:Int;
	var top:Int;
	var right:Int;
	var bottom:Int;
}
