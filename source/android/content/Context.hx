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

package android.content;

#if android
import lime.system.JNI;
#end

/**
 * Android context helpers, API-compatible with the extension-androidtools
 * surface used by `mobile.StorageUtil`.
 */
class Context
{
	/** Absolute path of the app's external files directory ("" when unavailable). */
	public static function getExternalFilesDir():String
	{
		#if android
		var path:String = getExternalFilesDir_jni();
		return path ?? "";
		#else
		return "";
		#end
	}

	#if android
	static var _getExternalFilesDir:Dynamic = null;

	static function getExternalFilesDir_jni():String
	{
		if (_getExternalFilesDir == null)
			_getExternalFilesDir = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getExternalFilesDir',
				'()Ljava/lang/String;');
		return _getExternalFilesDir();
	}
	#end
}
