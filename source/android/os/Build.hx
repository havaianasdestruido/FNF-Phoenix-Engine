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

package android.os;

#if android
import lime.system.JNI;
#end

/**
 * Android build information, API-compatible with the extension-androidtools
 * surface used by `mobile.StorageUtil`.
 */
class Build
{
	/** Current Android SDK version (0 outside of Android). */
	public static var SDK_INT(get, never):Int;

	static inline function get_SDK_INT():Int
		return VERSION.SDK_INT;
}

/** The Android SDK version running on the device. */
class VERSION
{
	/** android.os.Build.VERSION.SDK_INT */
	public static var SDK_INT(get, never):Int;

	static var cachedSDKInt:Int = -1;

	static function get_SDK_INT():Int
	{
		#if android
		if (cachedSDKInt < 0)
			cachedSDKInt = getSDKInt_jni();
		return cachedSDKInt;
		#else
		return 0;
		#end
	}

	#if android
	static var _getSDKInt:Dynamic = null;

	static function getSDKInt_jni():Int
	{
		if (_getSDKInt == null)
			_getSDKInt = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getSDKInt', '()I');
		return _getSDKInt();
	}
	#end
}

/**
 * Android version codes. These are immutable constants in Android's public
 * API, so they are mirrored here directly instead of going through JNI
 * (which would also fail on devices older than the constant's introduction).
 */
class VERSION_CODES
{
	public static inline final BASE:Int = 1;
	public static inline final BASE_1_1:Int = 2;
	public static inline final CUPCAKE:Int = 3;
	public static inline final DONUT:Int = 4;
	public static inline final ECLAIR:Int = 5;
	public static inline final ECLAIR_0_1:Int = 6;
	public static inline final ECLAIR_MR1:Int = 7;
	public static inline final FROYO:Int = 8;
	public static inline final GINGERBREAD:Int = 9;
	public static inline final GINGERBREAD_MR1:Int = 10;
	public static inline final HONEYCOMB:Int = 11;
	public static inline final HONEYCOMB_MR1:Int = 12;
	public static inline final HONEYCOMB_MR2:Int = 13;
	public static inline final ICE_CREAM_SANDWICH:Int = 14;
	public static inline final ICE_CREAM_SANDWICH_MR1:Int = 15;
	public static inline final JELLY_BEAN:Int = 16;
	public static inline final JELLY_BEAN_MR1:Int = 17;
	public static inline final JELLY_BEAN_MR2:Int = 18;
	public static inline final KITKAT:Int = 19;
	public static inline final KITKAT_WATCH:Int = 20;
	public static inline final LOLLIPOP:Int = 21;
	public static inline final LOLLIPOP_MR1:Int = 22;
	public static inline final M:Int = 23;
	public static inline final N:Int = 24;
	public static inline final N_MR1:Int = 25;
	public static inline final O:Int = 26;
	public static inline final O_MR1:Int = 27;
	public static inline final P:Int = 28;
	public static inline final Q:Int = 29;
	public static inline final R:Int = 30;
	public static inline final S:Int = 31;
	public static inline final S_V2:Int = 32;
	public static inline final TIRAMISU:Int = 33;
	public static inline final UPSIDE_DOWN_CAKE:Int = 34;
	public static inline final VANILLA_ICE_CREAM:Int = 35;
	public static inline final BAKLAVA:Int = 36;
}
