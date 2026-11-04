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
 * Non-standard Android hardware triggers (currently the volume buttons)
 * exposed as bindable game input.
 *
 * While enabled, KEYCODE_VOLUME_UP/DOWN no longer change the system volume;
 * they fire `onKey` instead, letting the engine map them to gameplay
 * actions. Only enable this in contexts where the user opted in (e.g. a
 * keybind screen chose volume triggers), and disable it everywhere else so
 * normal volume control keeps working.
 */
class AndroidHardwareInput
{
	// android.view.KeyEvent keycodes for the volume rocker.
	public static inline final KEYCODE_VOLUME_UP:Int = 24;
	public static inline final KEYCODE_VOLUME_DOWN:Int = 25;

	/** Fired for every intercepted hardware key: keyCode, isDown. */
	public static var onKey(get, never):FlxTypedSignal<Int->Bool->Void>;

	static inline function get_onKey():FlxTypedSignal<Int->Bool->Void>
		return AndroidBridge.onHardwareKey;

	static var intercepting(default, null):Bool = false;

	/** Starts intercepting the volume keys as game input. */
	public static function enableVolumeKeys():Void
	{
		#if android
		intercepting = true;
		AndroidBridge.ensureRegistered();
		setVolumeKeysIntercepted_jni(true);
		#end
	}

	/** Restores normal system volume key behavior. */
	public static function disableVolumeKeys():Void
	{
		#if android
		intercepting = false;
		setVolumeKeysIntercepted_jni(false);
		#end
	}

	public static function areVolumeKeysEnabled():Bool
	{
		return intercepting;
	}

	#if android
	static var _setVolumeKeysIntercepted:Dynamic = null;

	static function setVolumeKeysIntercepted_jni(intercept:Bool):Void
	{
		if (_setVolumeKeysIntercepted == null)
			_setVolumeKeysIntercepted = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'setVolumeKeysIntercepted', '(Z)V');
		_setVolumeKeysIntercepted(intercept);
	}
	#end
}
