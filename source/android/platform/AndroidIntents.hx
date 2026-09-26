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
 * Common Android intents: opening URLs, files and Settings pages, and
 * sharing content through the native share sheet.
 */
class AndroidIntents
{
	/** Incoming phoenix:// deep links (also fired for the cold-start intent). */
	public static var onDeepLink(get, never):FlxTypedSignal<String->Void>;

	static inline function get_onDeepLink():FlxTypedSignal<String->Void>
		return AndroidBridge.onDeepLink;

	/** Opens a URL in the system browser. */
	public static function openUrl(url:String):Void
	{
		#if android
		openUrl_jni(url);
		#end
	}

	/**
	 * Opens a Settings page. Pass either a full action
	 * ("android.settings.APPLICATION_DETAILS_SETTINGS") or a short name
	 * ("WIFI_SETTINGS"); empty opens the main Settings screen.
	 */
	public static function openSettings(?action:String):Void
	{
		#if android
		openSettings_jni(action ?? "");
		#end
	}

	/** Opens a local file with whatever app handles its type. */
	public static function openFile(path:String):Void
	{
		#if android
		openFile_jni(path);
		#end
	}

	/** Shares a local file through Android's share sheet. */
	public static function shareFile(path:String, ?mime:String, ?title:String):Void
	{
		#if android
		shareFile_jni(path, mime ?? "", title ?? "");
		#end
	}

	/** Shares text through Android's share sheet. */
	public static function shareText(text:String, ?title:String):Void
	{
		#if android
		shareText_jni(text, title ?? "");
		#end
	}

	/** Opens a content:// URI with an external app. */
	public static function viewContentUri(uri:String, ?mime:String):Void
	{
		#if android
		viewContentUri_jni(uri, mime ?? "*/*");
		#end
	}

	// ------------------------------------------------------------------
	// JNI bindings
	// ------------------------------------------------------------------

	#if android
	static var _openUrl:Dynamic = null;

	static function openUrl_jni(url:String):Void
	{
		if (_openUrl == null)
			_openUrl = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'openUrl', '(Ljava/lang/String;)V');
		_openUrl(url);
	}

	static var _openSettings:Dynamic = null;

	static function openSettings_jni(action:String):Void
	{
		if (_openSettings == null)
			_openSettings = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'openSettings', '(Ljava/lang/String;)V');
		_openSettings(action);
	}

	static var _openFile:Dynamic = null;

	static function openFile_jni(path:String):Void
	{
		if (_openFile == null)
			_openFile = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'openFile', '(Ljava/lang/String;)V');
		_openFile(path);
	}

	static var _shareFile:Dynamic = null;

	static function shareFile_jni(path:String, mime:String, title:String):Void
	{
		if (_shareFile == null)
			_shareFile = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'shareFile',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V');
		_shareFile(path, mime, title);
	}

	static var _shareText:Dynamic = null;

	static function shareText_jni(text:String, title:String):Void
	{
		if (_shareText == null)
			_shareText = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'shareText',
				'(Ljava/lang/String;Ljava/lang/String;)V');
		_shareText(text, title);
	}

	static var _viewContentUri:Dynamic = null;

	static function viewContentUri_jni(uri:String, mime:String):Void
	{
		if (_viewContentUri == null)
			_viewContentUri = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'viewContentUri',
				'(Ljava/lang/String;Ljava/lang/String;)V');
		_viewContentUri(uri, mime);
	}
	#end
}
