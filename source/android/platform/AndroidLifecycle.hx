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

import flixel.FlxG;
import flixel.util.FlxSignal;

/**
 * Exposes Android Activity lifecycle events to Haxe and keeps gameplay/audio
 * state in sync when the app loses or regains focus.
 *
 * Signals are re-exposed here for convenience; they are the same objects as
 * the ones on `AndroidBridge`.
 */
class AndroidLifecycle
{
	/** Every lifecycle event: onCreate/onStart/onResume/onPause/onStop/onRestart/onDestroy. */
	public static var onEvent(get, never):FlxTypedSignal<String->Void>;

	/** The Activity became visible and interactive again. */
	public static var onResume(get, never):FlxSignal;

	/** The Activity is no longer in the foreground (backgrounded). */
	public static var onPause(get, never):FlxSignal;

	/** The Activity is fully hidden. */
	public static var onStop(get, never):FlxSignal;

	/** The Activity is being created (cold start). */
	public static var onCreate(get, never):FlxSignal;

	/** The Activity is being destroyed. */
	public static var onDestroy(get, never):FlxSignal;

	/** True between onResume and onPause. */
	public static var inForeground(default, null):Bool = true;

	static var initialized:Bool = false;
	static var onResumeSignal:FlxSignal = new FlxSignal();
	static var onPauseSignal:FlxSignal = new FlxSignal();
	static var onStopSignal:FlxSignal = new FlxSignal();
	static var onCreateSignal:FlxSignal = new FlxSignal();
	static var onDestroySignal:FlxSignal = new FlxSignal();

	static inline function get_onEvent():FlxTypedSignal<String->Void>
		return AndroidBridge.onLifecycleEvent;

	static inline function get_onResume():FlxSignal
		return onResumeSignal;

	static inline function get_onPause():FlxSignal
		return onPauseSignal;

	static inline function get_onStop():FlxSignal
		return onStopSignal;

	static inline function get_onCreate():FlxSignal
		return onCreateSignal;

	static inline function get_onDestroy():FlxSignal
		return onDestroySignal;

	/**
	 * Starts listening to lifecycle events. When `autoPause` is true the
	 * engine automatically pauses/resumes music when the Activity
	 * backgrounds/foregrounds (Flixel's own focus handling covers most of
	 * this; the hook exists for targets where it does not fire reliably).
	 */
	public static function init(autoPause:Bool = true):Void
	{
		if (initialized || !AndroidBridge.available)
			return;

		initialized = true;
		AndroidBridge.ensureRegistered();

		AndroidBridge.onLifecycleEvent.add(function(event:String)
		{
			switch (event)
			{
				case 'onCreate':
					inForeground = false;
					onCreateSignal.dispatch();
				case 'onResume':
					inForeground = true;
					if (autoPause)
						resumeAudio();
					onResumeSignal.dispatch();
				case 'onPause':
					inForeground = false;
					if (autoPause)
						pauseAudio();
					onPauseSignal.dispatch();
				case 'onStop':
					onStopSignal.dispatch();
				case 'onDestroy':
					onDestroySignal.dispatch();
			}
		});
	}

	static function pauseAudio():Void
	{
		#if android
		try
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				FlxG.sound.music.pause();
		}
		catch (e:Dynamic) {}
		#end
	}

	static function resumeAudio():Void
	{
		#if android
		try
		{
			if (FlxG.sound.music != null && !FlxG.sound.music.playing && FlxG.sound.music.time > 0)
				FlxG.sound.music.resume();
		}
		catch (e:Dynamic) {}
		#end
	}
}
