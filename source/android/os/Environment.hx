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
 * Android external storage helpers, API-compatible with the
 * extension-androidtools surface used by `mobile.StorageUtil`.
 */
class Environment
{
	/** Absolute path of the shared external storage root ("" when unavailable). */
	public static function getExternalStorageDirectory():String
	{
		#if android
		var path:String = getExternalStorageDirectory_jni();
		return path ?? "";
		#else
		return "";
		#end
	}

	/**
	 * Whether the app holds the All Files Access role (API 30+).
	 * Always false on older Android versions, where classic storage applies.
	 */
	public static function isExternalStorageManager():Bool
	{
		#if android
		return isExternalStorageManager_jni();
		#else
		return false;
		#end
	}

	#if android
	static var _getExternalStorageDirectory:Dynamic = null;

	static function getExternalStorageDirectory_jni():String
	{
		if (_getExternalStorageDirectory == null)
			_getExternalStorageDirectory = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getExternalStorageDirectory',
				'()Ljava/lang/String;');
		return _getExternalStorageDirectory();
	}

	static var _isExternalStorageManager:Dynamic = null;

	static function isExternalStorageManager_jni():Bool
	{
		if (_isExternalStorageManager == null)
			_isExternalStorageManager = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'isExternalStorageManager', '()Z');
		return _isExternalStorageManager();
	}
	#end
}
