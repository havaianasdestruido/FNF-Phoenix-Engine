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

package android;

#if android
import lime.system.JNI;
#end

/**
 * Runtime permission helpers backed by the in-tree Phoenix native bridge
 * (API-compatible with the extension-androidtools surface used by
 * `mobile.StorageUtil`).
 */
class Permissions
{
	/**
	 * Requests the given runtime permissions (short names like
	 * "READ_MEDIA_IMAGES" or full "android.permission.*" names).
	 */
	public static function requestPermissions(permissions:Array<String>):Void
	{
		#if android
		if (permissions == null || permissions.length == 0)
			return;
		requestPermissions_jni(permissions.join(','));
		#end
	}

	/** Returns the permissions from the known list that are currently granted. */
	public static function getGrantedPermissions():Array<String>
	{
		#if android
		var csv:String = getGrantedPermissions_jni(KNOWN_PERMISSIONS);
		if (csv == null || csv.length == 0)
			return [];
		return csv.split(',');
		#else
		return [];
		#end
	}

	#if android
	static final KNOWN_PERMISSIONS:String = [
		'android.permission.READ_MEDIA_IMAGES',
		'android.permission.READ_MEDIA_VIDEO',
		'android.permission.READ_MEDIA_AUDIO',
		'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
		'android.permission.READ_EXTERNAL_STORAGE',
		'android.permission.WRITE_EXTERNAL_STORAGE',
		'android.permission.MANAGE_EXTERNAL_STORAGE',
		'android.permission.POST_NOTIFICATIONS'
	].join(',');

	static var _requestPermissions:Dynamic = null;

	static function requestPermissions_jni(csv:String):Void
	{
		if (_requestPermissions == null)
			_requestPermissions = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'requestPermissions', '(Ljava/lang/String;)V');
		_requestPermissions(csv);
	}

	static var _getGrantedPermissions:Dynamic = null;

	static function getGrantedPermissions_jni(csv:String):String
	{
		if (_getGrantedPermissions == null)
			_getGrantedPermissions = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getGrantedPermissions',
				'(Ljava/lang/String;)Ljava/lang/String;');
		return _getGrantedPermissions(csv);
	}
	#end
}
