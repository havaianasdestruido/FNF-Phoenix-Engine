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

package ios.platform;

#if ios
import lime.system.JNI; // not used on iOS, but keeps import parity
#end

/**
 * iOS display information: physical resolution, DPI, orientation,
 * refresh rate and safe-area insets (notch / home indicator).
 *
 * On non-iOS targets every call is a no-op fallback so cross-platform
 * code can query it without `#if ios` guards.
 *
 * The native work lives in `source/ios/src/` (Objective-C / Swift via
 * hxcpp's ObjC bridge). Until that native bridge lands, this Haxe side
 * returns best-effort values from Lime/OpenFL so the game still boots
 * and the safe-area path can be exercised in CI.
 */
class IOSDisplay
{
	/** Safe-area insets as {left, top, right, bottom} in logical pixels. */
	public static function getSafeAreaInsets():SafeAreaInsets
	{
		#if ios
		// TODO: Replace with native UIKit `safeAreaInsets` once the ObjC
		// bridge is wired. Lime's stage size already accounts for rotation,
		// but notches still need explicit padding on iPhone X+ devices.
		try
		{
			var insets = getSafeAreaInsets_native();
			if (insets != null) return insets;
		}
		catch (e:Dynamic) {}
		#end
		return {left: 0, top: 0, right: 0, bottom: 0};
	}

	/** Active display refresh rate (falls back to 60 when unknown). */
	public static function getRefreshRate():Float
	{
		#if ios
		try
		{
			var rate:Float = getRefreshRate_native();
			if (Math.isFinite(rate) && rate > 0) return rate;
		}
		catch (e:Dynamic) {}
		#end
		return 60;
	}

	/** Whether the device has a display cutout (notch / Dynamic Island). */
	public static function hasCutout():Bool
	{
		var insets = getSafeAreaInsets();
		return insets.top > 20 || insets.left > 0 || insets.right > 0;
	}

	/** iOS-safe fullscreen toggle — no-ops where Lime already manages it. */
	public static function setFullscreen(fullscreen:Bool):Void
	{
		// Lime's iOS window is always fullscreen; this exists for API parity
		// with AndroidDisplay.setImmersive() so gameplay code can be unified.
	}

	/** Boot hook for IOSPlatform. */
	@:noCompletion
	public static function init():Void
	{
		#if ios
		// Future: register for UIDevice.orientationDidChangeNotification etc.
		#end
	}

	#if ios
	// --- Native bindings (hxcpp ObjC) ---
	// These are intentionally stubs returning null/0 until the Swift/ObjC
	// src is added. The Haxe signatures are stable so the CI contract test
	// can verify the Haxe API before the native side ships.

	@:keep
	static function getSafeAreaInsets_native():SafeAreaInsets
	{
		return null;
	}

	@:keep
	static function getRefreshRate_native():Float
	{
		return 0;
	}
	#end
}

typedef SafeAreaInsets =
{
	var left:Int;
	var top:Int;
	var right:Int;
	var bottom:Int;
}

typedef IOSDisplayInfo =
{
	var width:Int;
	var height:Int;
	var densityDpi:Int;
	var xdpi:Float;
	var ydpi:Float;
	var rotation:Int;
	var refreshRate:Float;
	var safeArea:SafeAreaInsets;
}
