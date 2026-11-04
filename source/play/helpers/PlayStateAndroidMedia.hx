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
import backend.Paths;
import backend.PhoenixVersion;
import flixel.FlxG;
import openfl.utils.AssetType;
import flixel.util.FlxTimer;
import haxe.Json;
import StringTools;
import play.PlayState;
import states.substates.PauseSubState;
#end

/**
 * Wires Android's Media3 MediaSession (lock-screen / Bluetooth / Android Auto
 * controls), audio focus and wake lock into gameplay. The native player only
 * mirrors Flixel; it never decodes a second copy of the chart audio. No-op on
 * every other platform — the module only compiles its body on Android.
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

	static var recoveryTimer:FlxTimer = null;
	static var lastRecoveryPosition:Float = 0;
	static var lastPlaybackPosition:Float = 0;
	static var lastPlaybackTime:Float = 0;

	/** Build the recovery blob: enough to resume exactly where the OS killed the process. */
	static function buildRecoveryBlob():String
	{
		try
		{
			var blob:Dynamic = {
				type: "song",
				song: PlayState.SONG != null ? PlayState.SONG.song : null,
				difficulty: CoolUtil.difficultyString(),
				difficulties: CoolUtil.difficulties,
				mod: Mods.currentModDirectory,
				songPosition: Conductor.songPosition,
				playbackRate: state != null ? state.playbackRate : 1.0,
				health: state != null ? state.health : 1.0,
				practiceMode: state != null ? state.practiceMode : false,
				botplay: state != null ? state.cpuControlled : false,
				score: state != null ? state.songScore : 0,
				engineVersion: PhoenixVersion.current,
				timestamp: Date.now().getTime()
			};
			return Json.stringify(blob);
		}
		catch (e:Dynamic)
		{
			return "";
		}
	}

	static function persistRecoveryState():Void
	{
		var blob:String = buildRecoveryBlob();
		if (blob.length > 0)
			AndroidSystem.setRecoveryState(blob);
	}

	/** Begin presenting the current song to Android's media system. */
	public static function start(playState:play.PlayState):Void
	{
		stop(playState); // detach any previous wiring (defensive)
		state = playState;

		var title:String = PlayState.SONG != null ? PlayState.SONG.song : "Unknown";
		var artist:String = getSongArtist();
		var album:String = "Friday Night Funkin' - Phoenix Engine";
		var artworkPath:String = getSongArtworkPath();
		var duration:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;
		var initiallyPlaying:Bool = FlxG.sound.music != null && FlxG.sound.music.playing;

		// The chart carries the creator credit and optional creator image. Feed
		// both into Media3 rather than publishing every song as a generic FNF
		// track, while preserving a useful fallback for older/mod charts.
		AndroidMedia.updateNowPlaying(title, artist, duration, album, artworkPath);
		// Do not advertise buffering/playWhenReady before Flixel has actually
		// started sound. PhoenixMedia asks Media3 to start its service only when
		// a later STATE_PLAYING update mirrors real playback.
		AndroidMedia.setPlaybackState(initiallyPlaying ? AndroidMedia.STATE_PLAYING : AndroidMedia.STATE_PAUSED, 0,
			playState.playbackRate);
		AndroidMedia.requestAudioFocus();
		AndroidSystem.acquireWakeLock();

		// Persist enough context to offer a resume after process death
		// (TitleState.checkRecoveryState consumes it). The difficulty list
		// and mod directory are included because both are gone after a
		// process kill and chart paths depend on them. Now also includes
		// songPosition, playbackRate, health/practice state and engine version
		// so Resume continues where the OS killed the process and a blob
		// written by another build is rejected instead of half-applied.
		persistRecoveryState();
		lastRecoveryPosition = Conductor.songPosition;

		AndroidMedia.onPlay.add(onMediaPlay);
		AndroidMedia.onPause.add(onMediaPause);
		AndroidMedia.onStop.add(onMediaStop);
		AndroidMedia.onAudioFocusChanged.add(onAudioFocusChanged);

		// Keep the media UI's playback position fresh — rate-aware and frequent
		// enough that lock-screen / Android Auto interpolates smoothly.
		// Media3 can interpolate from PlaybackState position + speed, but the
		// engine must push an accurate position/speed pair; drifting 1s steps
		// cause visible stutter during rate changes.
		lastPlaybackPosition = Conductor.songPosition > 0 ? Conductor.songPosition : 0;
		lastPlaybackTime = haxe.Timer.stamp();
		updateTimer = new FlxTimer().start(0.5, function(_)
		{
			refreshPlaybackState();
		}, 0);

		// Periodically refresh the recovery blob so "Resume" is close to the
		// kill point even on long songs. Throttled to 2s / 5s position delta.
		recoveryTimer = new FlxTimer().start(2, function(_)
		{
			if (state == null || state.paused || state.endingSong) return;
			var pos:Float = Conductor.songPosition;
			if (Math.abs(pos - lastRecoveryPosition) > 5000)
			{
				lastRecoveryPosition = pos;
				persistRecoveryState();
			}
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
		if (recoveryTimer != null)
		{
			recoveryTimer.cancel();
			recoveryTimer = null;
		}

		AndroidMedia.onPlay.remove(onMediaPlay);
		AndroidMedia.onPause.remove(onMediaPause);
		AndroidMedia.onStop.remove(onMediaStop);
		AndroidMedia.onAudioFocusChanged.remove(onAudioFocusChanged);

		if (state != null)
		{
			if (ducked && FlxG.sound.music != null)
				FlxG.sound.music.volume = volumeBeforeDuck;
			ducked = false;

			AndroidMedia.abandonAudioFocus();
			AndroidSystem.releaseWakeLock();
			AndroidSystem.setRecoveryState("");
			AndroidMedia.stop();
			state = null;
		}
		lastRecoveryPosition = 0;
		lastPlaybackPosition = 0;
		lastPlaybackTime = 0;
	}

	static function refreshPlaybackState():Void
	{
		if (state == null)
			return;

		// Rate-aware position: interpolate from last reported position + elapsed * speed
		// so Media3 clients (lock screen, Auto) see smooth progress between Haxe ticks.
		var now:Float = haxe.Timer.stamp();
		var elapsedMs:Float = (now - lastPlaybackTime) * 1000;
		var basePosition:Float = Conductor.songPosition > 0 ? Conductor.songPosition : 0;
		// If the engine's reported position is close to our predicted one, use predicted
		// to avoid 500ms-step jitter; otherwise resync to engine truth.
		var predicted:Float = lastPlaybackPosition + elapsedMs * state.playbackRate;
		var position:Float = basePosition;
		if (state.playbackRate != 0 && Math.abs(basePosition - predicted) < 800)
			position = predicted;
		lastPlaybackPosition = position;
		lastPlaybackTime = now;

		var musicIsPlaying:Bool = FlxG.sound.music != null && FlxG.sound.music.playing;
		if (state.paused)
			AndroidMedia.setPlaybackState(AndroidMedia.STATE_PAUSED, position, state.playbackRate);
		else if (musicIsPlaying && !state.endingSong)
			// playbackRate is the actual Flixel sound pitch; songSpeed only
			// controls chart/note scrolling and would report a wrong timeline
			// speed to Android media clients.
			AndroidMedia.setPlaybackState(AndroidMedia.STATE_PLAYING, position, state.playbackRate);
		else
			// A selected-but-not-playing song is paused, not buffering: Media3
			// treats playWhenReady + BUFFERING as foreground-playback eligible.
			AndroidMedia.setPlaybackState(AndroidMedia.STATE_PAUSED, position, state.playbackRate);
	}

	/** Returns a chart creator credit, with a stable fallback for old charts. */
	static function getSongArtist():String
	{
		var credit:String = PlayState.SONG != null ? PlayState.SONG.songCredit : null;
		if (credit != null && StringTools.trim(credit).length > 0)
			return credit;
		return "Friday Night Funkin'";
	}

	/**
	 * Resolves the optional song-creator image to a path Java can load from a
	 * mod directory or the Android AssetManager. The native side gracefully
	 * falls back to no artwork if a legacy chart's icon is absent.
	 */
	static function getSongArtworkPath():String
	{
		var icon:String = PlayState.SONG != null ? PlayState.SONG.songCreditIcon : null;
		if (icon == null || StringTools.trim(icon).length == 0)
			return "";

		try
		{
			return Paths.getPath('images/songCreators/$icon.png', AssetType.IMAGE, null, true);
		}
		catch (e:Dynamic)
		{
			return "";
		}
	}

	// ------------------------------------------------------------------
	// Media action handlers (map system actions onto gameplay)
	// ------------------------------------------------------------------

	static function onMediaPlay():Void
	{
		// Only resume from an actual pause menu; never resurrect a dead
		// state or dismiss unrelated substates (game over, results, ...).
		if (state == null || !state.exists || !state.paused)
			return;

		if (state.subState == null || !Std.isOfType(state.subState, PauseSubState))
			return;

		try
		{
			state.closeSubState();
		}
		catch (e:Dynamic) {}
	}

	static function onMediaPause():Void
	{
		if (state == null || !state.exists || state.paused)
			return;

		// Same guards update() applies to the PAUSE input.
		if (!state.startedCountdown || !state.canPause || state.heyStopTrying || state.endingSong || state.transitioning)
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

	/**
	 * True while audio focus has the instrumental ducked for another app (a call, a notification).
	 * Volume owners -- e.g. the global stem override in PlayStatePlayback -- must not fight the duck.
	 */
	public static function isDucking():Bool
	{
		return ducked;
	}
	#else
	public static function start(playState:play.PlayState):Void {}

	public static function stop(?playState:play.PlayState):Void {}

	/** Only Android ducks the instrumental for audio focus; everywhere else this is always false. */
	public static function isDucking():Bool
	{
		return false;
	}
	#end
}
