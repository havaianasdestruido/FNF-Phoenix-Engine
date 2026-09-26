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
 * Native Android notifications. The media (MediaStyle) notification is
 * managed by `AndroidMedia`; this module covers simple status notifications.
 */
class AndroidNotifications
{
	/**
	 * Posts a simple notification on the engine's general channel.
	 * On Android 13+ the user must have granted POST_NOTIFICATIONS
	 * (see `requestPermission`).
	 */
	public static function notify(id:Int, title:String, text:String):Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		notifySimple_jni(id, title ?? "", text ?? "");
		#end
	}

	public static function cancel(id:Int):Void
	{
		#if android
		cancelNotification_jni(id);
		#end
	}

	/** Requests the POST_NOTIFICATIONS runtime permission (Android 13+). */
	public static function requestPermission():Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		requestNotificationPermission_jni();
		#end
	}

	#if android
	static var _notifySimple:Dynamic = null;

	static function notifySimple_jni(id:Int, title:String, text:String):Void
	{
		if (_notifySimple == null)
			_notifySimple = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'notifySimple',
				'(ILjava/lang/String;Ljava/lang/String;)V');
		_notifySimple(id, title, text);
	}

	static var _cancelNotification:Dynamic = null;

	static function cancelNotification_jni(id:Int):Void
	{
		if (_cancelNotification == null)
			_cancelNotification = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixMedia', 'cancelNotification', '(I)V');
		_cancelNotification(id);
	}

	static var _requestNotificationPermission:Dynamic = null;

	static function requestNotificationPermission_jni():Void
	{
		if (_requestNotificationPermission == null)
			_requestNotificationPermission = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'requestNotificationPermission', '()V');
		_requestNotificationPermission();
	}
	#end
}
