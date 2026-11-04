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

#if android
import lime.system.JNI;
#end

/**
 * Android vibration/haptic feedback for gameplay events, menu interactions
 * and anything else the engine wants to make tactile.
 */
class AndroidHaptics
{
	/** True when the device has a vibrator. */
	public static function isSupported():Bool
	{
		#if android
		return hasVibrator_jni();
		#else
		return false;
		#end
	}

	/** Single vibration burst. */
	public static function vibrate(durationMs:Int = 50):Void
	{
		#if android
		vibrate_jni(durationMs);
		#end
	}

	/**
	 * Patterned vibration.
	 * @param pattern alternating wait/vibrate timings in ms, e.g. [0, 40, 60, 40]
	 * @param repeat  pattern index to loop from, -1 for no repeat
	 */
	public static function vibratePattern(pattern:Array<Int>, repeat:Int = -1):Void
	{
		#if android
		if (pattern == null || pattern.length == 0)
			return;
		vibratePattern_jni(pattern.join(','), repeat);
		#end
	}

	/** Stops any in-flight vibration. */
	public static function cancel():Void
	{
		#if android
		cancelVibration_jni();
		#end
	}

	// Convenience presets for rhythm-game feedback.
	public static inline function light():Void
		vibrate(15);

	public static inline function medium():Void
		vibrate(35);

	public static inline function heavy():Void
		vibrate(70);

	#if android
	static var _hasVibrator:Dynamic = null;

	static function hasVibrator_jni():Bool
	{
		if (_hasVibrator == null)
			_hasVibrator = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'hasVibrator', '()Z');
		return _hasVibrator();
	}

	static var _vibrate:Dynamic = null;

	static function vibrate_jni(durationMs:Int):Void
	{
		if (_vibrate == null)
			_vibrate = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'vibrate', '(J)V');
		_vibrate(durationMs);
	}

	static var _vibratePattern:Dynamic = null;

	static function vibratePattern_jni(patternCsv:String, repeat:Int):Void
	{
		if (_vibratePattern == null)
			_vibratePattern = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'vibratePattern', '(Ljava/lang/String;I)V');
		_vibratePattern(patternCsv, repeat);
	}

	static var _cancelVibration:Dynamic = null;

	static function cancelVibration_jni():Void
	{
		if (_cancelVibration == null)
			_cancelVibration = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'cancelVibration', '()V');
		_cancelVibration();
	}
	#end
}
