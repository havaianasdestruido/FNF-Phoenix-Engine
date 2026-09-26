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
import haxe.io.Bytes;
#if android
import lime.system.JNI;
#end

/**
 * Central JNI bridge between the Haxe engine and the Phoenix Android native
 * layer (`android/src/quack/fnf/phoenix/android/*.java`).
 *
 * Java pushes events through `onAndroidEvent(event, arg)` and storage
 * results through `onStorageResult(...)`; this class demultiplexes them
 * into the typed signals exposed by the `android.platform.*` modules.
 *
 * Everything here is safe to reference on every platform: outside of
 * Android the signals simply never fire and the bound helpers no-op.
 */
class AndroidBridge #if android implements lime.system.JNI.JNISafety #end
{
	/** True when running on a real Android build with the native layer available. */
	public static var available(get, never):Bool;

	static inline function get_available():Bool
	{
		return #if android true #else false #end;
	}

	static var registered:Bool = false;
	static var instance:AndroidBridge = null;

	// ------------------------------------------------------------------
	// Signals (fired on the main Haxe thread)
	// ------------------------------------------------------------------

	/** Lifecycle event names: onCreate/onStart/onResume/onPause/onStop/onRestart/onDestroy. */
	public static var onLifecycleEvent:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** Fired on Activity#onLowMemory. */
	public static var onLowMemory:FlxSignal = new FlxSignal();

	/** Fired on Activity#onTrimMemory with the trim level. */
	public static var onTrimMemory:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	/** Thermal status changes (API 30+): 0 = none ... 5 = shutdown. */
	public static var onThermalStatus:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	public static var onMediaPlay:FlxSignal = new FlxSignal();
	public static var onMediaPause:FlxSignal = new FlxSignal();
	public static var onMediaStop:FlxSignal = new FlxSignal();
	public static var onMediaNext:FlxSignal = new FlxSignal();
	public static var onMediaPrevious:FlxSignal = new FlxSignal();

	/** Seek request from the system media UI, position in milliseconds. */
	public static var onMediaSeek:FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

	/** Audio focus changes: "gain", "loss", "lossTransient", "duck". */
	public static var onFocusChanged:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** Gamepad device id connected. */
	public static var onGamepadConnected:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	/** Gamepad device id disconnected. */
	public static var onGamepadDisconnected:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	/** Gamepad device id changed (configuration update). */
	public static var onGamepadChanged:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	/** Hardware key events (volume keys as input): keyCode, isDown. */
	public static var onHardwareKey:FlxTypedSignal<Int->Bool->Void> = new FlxTypedSignal<Int->Bool->Void>();

	/** Display configuration changed (rotation/refresh/mode). */
	public static var onDisplayChanged:FlxSignal = new FlxSignal();

	/** Incoming phoenix:// deep link (or any VIEW data URI). */
	public static var onDeepLink:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** Non-launch intents that carried no data (informational). */
	public static var onIntentAction:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** Results of runtime permission requests (CSV of granted permissions). */
	public static var onPermissionsResult:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** Recovery state blob restored after a warm restart. */
	public static var onRecoveryState:FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	/** SAF picker results. */
	public static var onStorageResult:FlxTypedSignal<AndroidStorageResult->Void> = new FlxTypedSignal<AndroidStorageResult->Void>();

	// ------------------------------------------------------------------
	// Registration
	// ------------------------------------------------------------------

	/**
	 * Registers this dispatcher with the Java side. Called automatically by
	 * `AndroidPlatform.init()`; safe to call multiple times.
	 */
	public static function ensureRegistered():Void
	{
		#if android
		if (registered)
			return;

		registered = true;
		instance = new AndroidBridge();

		var registerCallback:Dynamic = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'registerCallback',
			'(Lorg/haxe/lime/HaxeObject;)V');
		registerCallback(instance);

		var registerStorageCallback:Dynamic = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'registerStorageCallback',
			'(Lorg/haxe/lime/HaxeObject;)V');
		registerStorageCallback(instance);
		#end
	}

	// ------------------------------------------------------------------
	// Java -> Haxe entry points
	// ------------------------------------------------------------------

	#if android
	@:runOnMainThread
	public function onAndroidEvent(event:String, arg:String):Void
	{
		if (arg == null)
			arg = "";

		switch (event)
		{
			case 'lifecycle':
				onLifecycleEvent.dispatch(arg);

			case 'memory':
				if (arg == 'low')
					onLowMemory.dispatch();
				else if (StringTools.startsWith(arg, 'trim:'))
					onTrimMemory.dispatch(Std.parseInt(arg.substr(5)) ?? 0);

			case 'thermal':
				onThermalStatus.dispatch(Std.parseInt(arg) ?? 0);

			case 'media':
				if (StringTools.startsWith(arg, 'seek:'))
					onMediaSeek.dispatch(Std.parseFloat(arg.substr(5)));
				else
				{
					switch (arg)
					{
						case 'play':
							onMediaPlay.dispatch();
						case 'pause':
							onMediaPause.dispatch();
						case 'stop':
							onMediaStop.dispatch();
						case 'next':
							onMediaNext.dispatch();
						case 'previous':
							onMediaPrevious.dispatch();
					}
				}

			case 'focus':
				onFocusChanged.dispatch(arg);

			case 'gamepad':
				var colonIndex = arg.indexOf(':');
				if (colonIndex > 0)
				{
					var kind = arg.substr(0, colonIndex);
					var id = Std.parseInt(arg.substr(colonIndex + 1)) ?? -1;
					switch (kind)
					{
						case 'added':
							onGamepadConnected.dispatch(id);
						case 'removed':
							onGamepadDisconnected.dispatch(id);
						case 'changed':
							onGamepadChanged.dispatch(id);
					}
				}

			case 'hwkey':
				var colonIndex = arg.indexOf(':');
				if (colonIndex > 0)
				{
					var down = arg.substr(0, colonIndex) == 'down';
					var code = Std.parseInt(arg.substr(colonIndex + 1)) ?? 0;
					onHardwareKey.dispatch(code, down);
				}

			case 'display':
				onDisplayChanged.dispatch();

			case 'deeplink':
				onDeepLink.dispatch(arg);

			case 'intent':
				onIntentAction.dispatch(arg);

			case 'permissions':
				onPermissionsResult.dispatch(arg);

			case 'recovery':
				onRecoveryState.dispatch(arg);
		}
	}

	@:runOnMainThread
	public function onStorageResult(requestCode:Int, resultCode:Int, uri:String, name:String, size:Float, bytes:Dynamic):Void
	{
		var data:Bytes = null;
		if (bytes != null)
		{
			try
			{
				data = Bytes.ofData(bytes);
			}
			catch (e:Dynamic)
			{
				data = null;
			}
		}

		onStorageResult.dispatch({
			request: requestCode,
			ok: resultCode == RESULT_OK,
			uri: uri ?? "",
			name: name ?? "",
			size: Std.int(size),
			data: data
		});
	}

	static inline final RESULT_OK:Int = -1; // android.app.Activity.RESULT_OK
	#end
}

/** Result of an Android Storage Access Framework picker. */
typedef AndroidStorageResult =
{
	/** One of AndroidStorage.REQUEST_* request codes. */
	var request:Int;

	/** Whether the user picked something (false = canceled). */
	var ok:Bool;

	/** The picked document/tree URI as a string ("" when canceled). */
	var uri:String;

	/** Display name of the picked document ("" when unknown). */
	var name:String;

	/** Size in bytes when known, otherwise -1 or 0. */
	var size:Int;

	/** File contents; only populated for open-document requests. */
	var data:Null<Bytes>;
}
