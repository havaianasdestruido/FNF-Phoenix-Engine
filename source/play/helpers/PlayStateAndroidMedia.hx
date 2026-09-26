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

package play.helpers;

#if android
import android.platform.AndroidMedia;
import android.platform.AndroidSystem;
import backend.Conductor;
import backend.CoolUtil;
import flixel.FlxG;
import flixel.util.FlxTimer;
import haxe.Json;
#end

/**
 * Wires Android's media system (MediaSession, lock screen / Bluetooth
 * controls, audio focus, wake lock) into gameplay. No-op on every other
 * platform — the module only compiles its body on Android.
 *
 * Started from PlayState.create(), stopped from PlayState.destroy().
 */
@:access(play.PlayState)
class PlayStateAndroidMedia
{
	#if android
	static var state:play.PlayState = null;
	static var updateTimer:FlxTimer = null;
	static var ducked:Bool = false;
	static var volumeBeforeDuck:Float = 1.0;

	/** Begin presenting the current song to Android's media system. */
	public static function start(playState:play.PlayState):Void
	{
		stop(playState); // detach any previous wiring (defensive)
		state = playState;

		var title:String = playState.SONG != null ? playState.SONG.song : "Unknown";
		var duration:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;

		AndroidMedia.updateNowPlaying(title, 'Friday Night Funkin\'', duration);
		AndroidMedia.setPlaybackState(AndroidMedia.STATE_PLAYING, 0);
		AndroidMedia.updateNotification(title, 'Friday Night Funkin\'', true);
		AndroidMedia.requestAudioFocus();
		AndroidSystem.acquireWakeLock();

		// Persist enough context to offer a resume after process death.
		try
		{
			AndroidSystem.setRecoveryState(Json.stringify({
				type: "song",
				song: playState.SONG != null ? playState.SONG.song : null,
				difficulty: CoolUtil.difficultyString()
			}));
		}
		catch (e:Dynamic) {}

		AndroidMedia.onPlay.add(onMediaPlay);
		AndroidMedia.onPause.add(onMediaPause);
		AndroidMedia.onStop.add(onMediaStop);
		AndroidMedia.onAudioFocusChanged.add(onAudioFocusChanged);

		// Keep the media UI's playback position fresh.
		updateTimer = new FlxTimer().start(1, function(_)
		{
			refreshPlaybackState();
		}, 0);
	}

	/** Tear down the session wiring (song over / state destroyed). */
	public static function stop(?playState:play.PlayState):Void
	{
		if (updateTimer != null)
		{
			updateTimer.cancel();
			updateTimer = null;
		}

		AndroidMedia.onPlay.remove(onMediaPlay);
		AndroidMedia.onPause.remove(onMediaPause);
		AndroidMedia.onStop.remove(onMediaStop);
		AndroidMedia.onAudioFocusChanged.remove(onAudioFocusChanged);

		if (state != null)
		{
			AndroidMedia.abandonAudioFocus();
			AndroidSystem.releaseWakeLock();
			AndroidSystem.setRecoveryState("");
			AndroidMedia.stop();
			state = null;
		}
	}

	static function refreshPlaybackState():Void
	{
		if (state == null)
			return;

		var position:Float = Conductor.songPosition > 0 ? Conductor.songPosition : 0;
		if (state.paused)
			AndroidMedia.setPlaybackState(AndroidMedia.STATE_PAUSED, position);
		else
			AndroidMedia.setPlaybackState(AndroidMedia.STATE_PLAYING, position, state.songSpeed);
	}

	// ------------------------------------------------------------------
	// Media action handlers (map system actions onto gameplay)
	// ------------------------------------------------------------------

	static function onMediaPlay():Void
	{
		if (state == null || !state.paused)
			return;

		// Resume exactly like dismissing the pause menu would.
		try
		{
			if (state.subState != null)
				state.closeSubState();
		}
		catch (e:Dynamic) {}
	}

	static function onMediaPause():Void
	{
		if (state == null || state.paused)
			return;

		try
		{
			state.openPauseMenu();
		}
		catch (e:Dynamic) {}
	}

	static function onMediaStop():Void
	{
		// Treat "stop" as pause; leaving the song mid-game would lose
		// progress, which is never what a media button should do here.
		onMediaPause();
	}

	static function onAudioFocusChanged(change:String):Void
	{
		if (state == null)
			return;

		switch (change)
		{
			case 'loss', 'lossTransient':
				if (!state.paused)
					onMediaPause();
			case 'duck':
				if (FlxG.sound.music != null && !ducked)
				{
					ducked = true;
					volumeBeforeDuck = FlxG.sound.music.volume;
					FlxG.sound.music.volume = volumeBeforeDuck * 0.35;
				}
			case 'gain':
				if (FlxG.sound.music != null && ducked)
				{
					FlxG.sound.music.volume = volumeBeforeDuck;
					ducked = false;
				}
		}
	}
	#else
	public static function start(playState:play.PlayState):Void {}

	public static function stop(?playState:play.PlayState):Void {}
	#end
}
