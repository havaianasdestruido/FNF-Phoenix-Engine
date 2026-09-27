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
#if android
import lime.system.JNI;
#end

/**
 * Device-state information: memory pressure, battery state, screen wake
 * locking and process-death recovery state.
 */
class AndroidSystem
{
	/** Fired when the system reports low memory. */
	public static var onLowMemory(get, never):FlxSignal;

	/** Fired on trim-memory requests with the trim level. */
	public static var onTrimMemory(get, never):FlxTypedSignal<Int->Void>;

	static inline function get_onLowMemory():FlxSignal
		return AndroidBridge.onLowMemory;

	static inline function get_onTrimMemory():FlxTypedSignal<Int->Void>
		return AndroidBridge.onTrimMemory;

	// ------------------------------------------------------------------
	// Battery
	// ------------------------------------------------------------------

	/**
	 * Battery information, or null when unavailable/non-Android.
	 */
	public static function getBatteryInfo():Null<BatteryInfo>
	{
		#if android
		var raw:String = getBatteryInfo_jni();
		if (raw == null || raw.length == 0)
			return null;

		var parts = raw.split('|');
		if (parts.length < 3)
			return null;

		return {
			level: Std.parseFloat(parts[0]),
			charging: parts[1] == 'true',
			plugged: Std.parseInt(parts[2]) ?? 0
		};
		#else
		return null;
		#end
	}

	// ------------------------------------------------------------------
	// Screen wake lock
	// ------------------------------------------------------------------

	/** Keeps the screen on (e.g. during gameplay). */
	public static function acquireWakeLock():Void
	{
		#if android
		acquireWakeLock_jni();
		#end
	}

	/** Allows the screen to turn off again. */
	public static function releaseWakeLock():Void
	{
		#if android
		releaseWakeLock_jni();
		#end
	}

	// ------------------------------------------------------------------
	// Process-death recovery
	// ------------------------------------------------------------------

	/**
	 * Persists an opaque state blob (JSON) that survives Android killing the
	 * process while backgrounded. Store whatever is needed to restore the
	 * user's context (e.g. current song + difficulty) and read it back with
	 * `consumeRecoveryState()` on the next startup.
	 */
	public static function setRecoveryState(state:String):Void
	{
		#if android
		setRecoveryState_jni(state ?? "");
		#end
	}

	/**
	 * Returns the persisted recovery blob and clears it. Returns "" when
	 * nothing was stored (or on non-Android targets).
	 */
	public static function consumeRecoveryState():String
	{
		#if android
		var state:String = getRecoveryState_jni();
		if (state != null && state.length > 0)
			setRecoveryState_jni("");
		return state ?? "";
		#else
		return "";
		#end
	}

	// ------------------------------------------------------------------
	// Device info
	// ------------------------------------------------------------------

	/** Android SDK version (0 on other platforms). */
	public static function getSDKInt():Int
	{
		#if android
		return getSDKInt_jni();
		#else
		return 0;
		#end
	}

	/** "manufacturer|model|device|arch" (empty on other platforms). */
	public static function getDeviceInfo():String
	{
		#if android
		var info:String = getDeviceInfo_jni();
		return info ?? "";
		#else
		return "";
		#end
	}

	// ------------------------------------------------------------------
	// JNI bindings
	// ------------------------------------------------------------------

	#if android
	static var _getBatteryInfo:Dynamic = null;

	static function getBatteryInfo_jni():String
	{
		if (_getBatteryInfo == null)
			_getBatteryInfo = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getBatteryInfo', '()Ljava/lang/String;');
		return _getBatteryInfo();
	}

	static var _acquireWakeLock:Dynamic = null;

	static function acquireWakeLock_jni():Void
	{
		if (_acquireWakeLock == null)
			_acquireWakeLock = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'acquireWakeLock', '()V');
		_acquireWakeLock();
	}

	static var _releaseWakeLock:Dynamic = null;

	static function releaseWakeLock_jni():Void
	{
		if (_releaseWakeLock == null)
			_releaseWakeLock = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'releaseWakeLock', '()V');
		_releaseWakeLock();
	}

	static var _setRecoveryState:Dynamic = null;

	static function setRecoveryState_jni(state:String):Void
	{
		if (_setRecoveryState == null)
			_setRecoveryState = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'setRecoveryState', '(Ljava/lang/String;)V');
		_setRecoveryState(state);
	}

	static var _getRecoveryState:Dynamic = null;

	static function getRecoveryState_jni():String
	{
		if (_getRecoveryState == null)
			_getRecoveryState = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getRecoveryState', '()Ljava/lang/String;');
		return _getRecoveryState();
	}

	static var _getSDKInt:Dynamic = null;

	static function getSDKInt_jni():Int
	{
		if (_getSDKInt == null)
			_getSDKInt = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getSDKInt', '()I');
		return _getSDKInt();
	}

	static var _getDeviceInfo:Dynamic = null;

	static function getDeviceInfo_jni():String
	{
		if (_getDeviceInfo == null)
			_getDeviceInfo = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getDeviceInfo', '()Ljava/lang/String;');
		return _getDeviceInfo();
	}
	#end
}

typedef BatteryInfo =
{
	/** Charge level from 0.0 to 1.0 (-1 when unknown). */
	var level:Float;

	/** Whether the battery is currently charging or full. */
	var charging:Bool;

	/** android.os.BatteryManager.EXTRA_PLUGGED value (0 = on battery). */
	var plugged:Int;
}
