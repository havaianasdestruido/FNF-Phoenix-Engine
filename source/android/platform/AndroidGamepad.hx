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
import haxe.Json;
#if android
import lime.system.JNI;
#end

/**
 * Native Android gamepad/controller support: connected device information,
 * connection/disconnection events, controller identification and rumble.
 *
 * Actual button/axis input is handled by Flixel's gamepad system (fed by
 * SDL on Android); this module provides the device-level information the
 * engine's keybind/input system needs on top of that.
 */
class AndroidGamepad
{
	public static var onConnected(get, never):FlxTypedSignal<Int->Void>;
	public static var onDisconnected(get, never):FlxTypedSignal<Int->Void>;

	/** Fired when Flixel sees a new gamepad (after `init()` wired things up). */
	public static var onFlixelGamepadAdded:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	static inline function get_onConnected():FlxTypedSignal<Int->Void>
		return AndroidBridge.onGamepadConnected;

	static inline function get_onDisconnected():FlxTypedSignal<Int->Void>
		return AndroidBridge.onGamepadDisconnected;

	static var initialized:Bool = false;

	/**
	 * Starts watching for controller connection changes and keeps Flixel's
	 * keybind system (`Controls.addDefaultGamepad`) in sync with newly
	 * connected pads.
	 */
	public static function init():Void
	{
		#if android
		if (initialized || !AndroidBridge.available)
			return;

		initialized = true;
		AndroidBridge.ensureRegistered();
		registerGamepadListener_jni();

		AndroidBridge.onGamepadConnected.add(function(id:Int)
		{
			onFlixelGamepadAdded.dispatch(id);
		});
		#end
	}

	/** All currently connected gamepad-like devices. */
	public static function getDevices():Array<GamepadInfo>
	{
		#if android
		var raw:String = getGamepads_jni();
		return parseDeviceList(raw);
		#else
		return [];
		#end
	}

	/** Information for a single device id (null when unavailable). */
	public static function getDevice(id:Int):Null<GamepadInfo>
	{
		#if android
		var raw:String = getDeviceInfo_jni(id);
		if (raw == null || raw == '{}' || raw.length == 0)
			return null;

		return parseDevice(raw);
		#else
		return null;
		#end
	}

	/** Vibrates a controller that has a built-in vibrator, returns success. */
	public static function vibrate(deviceId:Int, durationMs:Int = 200):Bool
	{
		#if android
		return vibrateGamepad_jni(deviceId, durationMs);
		#else
		return false;
		#end
	}

	/** Whether any gamepad is currently connected. */
	public static function anyConnected():Bool
	{
		return getDevices().length > 0;
	}

	#if android
	static function parseDeviceList(raw:String):Array<GamepadInfo>
	{
		var devices:Array<GamepadInfo> = [];
		if (raw == null || raw.length == 0)
			return devices;

		try
		{
			var list:Array<Dynamic> = Json.parse(raw);
			for (entry in list)
			{
				var device = parseDeviceEntry(entry);
				if (device != null)
					devices.push(device);
			}
		}
		catch (e:Dynamic) {}
		return devices;
	}

	static function parseDevice(raw:String):Null<GamepadInfo>
	{
		try
		{
			return parseDeviceEntry(Json.parse(raw));
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function parseDeviceEntry(entry:Dynamic):Null<GamepadInfo>
	{
		if (entry == null)
			return null;

		return {
			id: Std.parseInt(Std.string(entry.id)) ?? -1,
			name: Std.string(entry.name),
			descriptor: Std.string(entry.descriptor),
			vendorId: Std.parseInt(Std.string(entry.vendorId)) ?? 0,
			productId: Std.parseInt(Std.string(entry.productId)) ?? 0,
			hasVibrator: entry.hasVibrator == true,
			type: switch (Std.string(entry.type))
			{
				case 'xbox': XBOX;
				case 'playstation': PLAYSTATION;
				case 'nintendo': NINTENDO;
				case '8bitdo': RETRO;
				case 'steam': STEAM;
				default: GENERIC;
			}
		};
	}

	static var _registerGamepadListener:Dynamic = null;

	static function registerGamepadListener_jni():Void
	{
		if (_registerGamepadListener == null)
			_registerGamepadListener = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'registerGamepadListener', '()V');
		_registerGamepadListener();
	}

	static var _getGamepads:Dynamic = null;

	static function getGamepads_jni():String
	{
		if (_getGamepads == null)
			_getGamepads = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'getGamepads', '()Ljava/lang/String;');
		return _getGamepads();
	}

	static var _getDeviceInfo:Dynamic = null;

	static function getDeviceInfo_jni(id:Int):String
	{
		if (_getDeviceInfo == null)
			_getDeviceInfo = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'getDeviceInfo', '(I)Ljava/lang/String;');
		return _getDeviceInfo(id);
	}

	static var _vibrateGamepad:Dynamic = null;

	static function vibrateGamepad_jni(id:Int, durationMs:Int):Bool
	{
		if (_vibrateGamepad == null)
			_vibrateGamepad = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixInput', 'vibrateGamepad', '(IJ)Z');
		return _vibrateGamepad(id, durationMs);
	}
	#end
}

enum ControllerType
{
	XBOX;
	PLAYSTATION;
	NINTENDO;
	RETRO;
	STEAM;
	GENERIC;
}

typedef GamepadInfo =
{
	var id:Int;
	var name:String;
	var descriptor:String;
	var vendorId:Int;
	var productId:Int;
	var hasVibrator:Bool;
	var type:ControllerType;
}
