package play.helpers;

import backend.ClientPrefs;

import data.ExtraVocals;

/** A chart-declared extra vocal stem with its loaded sound. See `data.ExtraVocals`. */
class ExtraVocalTrack
{
	public var name:String;
	public var file:String;
	public var side:String;
	public var sound:FlxSound;

	public function new(stem:ExtraVocalStem, sound:FlxSound)
	{
		name = stem.name;
		file = stem.file;
		side = stem.side;
		this.sound = sound;
	}
}

/**
 * Runtime side of the chart-declared extra vocal stems
 * ("[P2] Unlimited vocals per strumline", docs/EXTRA_VOCALS.md).
 *
 * A chart's `extraVocals` array declares any number of additional vocal
 * tracks; each becomes its own `FlxSound` that plays in sync with the
 * player/opponent stems and follows the muting rules of the strumline side it
 * is bound to. Everything here is a no-op on an empty track list, so songs
 * without extra vocals pay nothing.
 */
class PlayStateExtraVocals
{
	/**
	 * Loads the stems declared by `raw` (a chart's `extraVocals` field), each
	 * into its own `FlxSound` registered with `FlxG.sound.list` — the same
	 * lifecycle as the player/opponent stems. Missing files are skipped with a
	 * log line instead of breaking the song, and the whole feature bows out
	 * when the player disabled it (Options -> Gameplay -> Extra Vocal Stems).
	 */
	public static function load(raw:Dynamic, song:String, diff:String, stream:Bool):Array<ExtraVocalTrack>
	{
		final tracks:Array<ExtraVocalTrack> = [];
		if (!ClientPrefs.extraVocals) return tracks;

		for (stem in ExtraVocals.parse(raw))
		{
			var file:Any = null;
			try
			{
				file = Paths.voices(song, diff, stem.file.length > 0 ? stem.file : null, stream);
			}
			catch (e:Dynamic) {}
			if (file == null)
			{
				FlxG.log.add('Extra vocal stem "${stem.name}": no Voices-${stem.file} audio found for $song, skipping.');
				continue;
			}

			final sound:FlxSound = new FlxSound();
			try
			{
				sound.loadEmbedded(file);
			}
			catch (e:Dynamic)
			{
				FlxG.log.add('Extra vocal stem "${stem.name}" ($song/Voices-${stem.file}) failed to load, skipping.');
				continue;
			}
			FlxG.sound.list.add(sound);
			tracks.push(new ExtraVocalTrack(stem, sound));
		}
		return tracks;
	}

	/** Stops, unregisters and destroys every track (state teardown / reload). */
	public static function dispose(tracks:Array<ExtraVocalTrack>):Void
	{
		if (tracks == null) return;
		for (track in tracks)
		{
			if (track.sound == null) continue;
			track.sound.stop();
			FlxG.sound.list.remove(track.sound);
			track.sound.destroy();
			track.sound = null;
		}
		tracks.resize(0);
	}

	/** Finds a stem by its chart-declared name (scripting API lookup). */
	public static function find(tracks:Array<ExtraVocalTrack>, name:String):Null<ExtraVocalTrack>
	{
		if (tracks == null || name == null) return null;
		for (track in tracks)
			if (track.name == name) return track;
		return null;
	}

	/** The chart-declared stem names, in chart order. */
	public static function names(tracks:Array<ExtraVocalTrack>):Array<String>
	{
		final result:Array<String> = [];
		if (tracks != null)
			for (track in tracks) result.push(track.name);
		return result;
	}

	/** Plays every stem still inside its audio (mirrors the vocal resync loops). */
	public static function playAll(tracks:Array<ExtraVocalTrack>):Void
	{
		if (tracks == null) return;
		for (track in tracks)
		{
			final sound:FlxSound = track.sound;
			if (sound != null && sound.time <= sound.length) sound.play();
		}
	}

	public static function stopAll(tracks:Array<ExtraVocalTrack>):Void
	{
		if (tracks == null) return;
		for (track in tracks)
			if (track.sound != null) track.sound.stop();
	}

	/** Pauses like `PlayStatePlayback.pauseVocals`: past-the-end stems stay put. */
	public static function pauseAll(tracks:Array<ExtraVocalTrack>):Void
	{
		if (tracks == null) return;
		final musicLength:Float = FlxG.sound.music != null ? FlxG.sound.music.length : Math.POSITIVE_INFINITY;
		for (track in tracks)
		{
			final sound:FlxSound = track.sound;
			if (sound != null && sound.time <= musicLength) sound.pause();
		}
	}

	public static function resumeAll(tracks:Array<ExtraVocalTrack>):Void
	{
		if (tracks == null) return;
		final musicLength:Float = FlxG.sound.music != null ? FlxG.sound.music.length : Math.POSITIVE_INFINITY;
		for (track in tracks)
		{
			final sound:FlxSound = track.sound;
			if (sound != null && sound.time <= musicLength) sound.resume();
		}
	}

	/** Seeks every stem that has not run past its audio yet. */
	public static function setTimeAll(tracks:Array<ExtraVocalTrack>, time:Float):Void
	{
		if (tracks == null) return;
		for (track in tracks)
		{
			final sound:FlxSound = track.sound;
			if (sound != null && sound.time < sound.length) sound.time = time;
		}
	}

	public static function setPitchAll(tracks:Array<ExtraVocalTrack>, pitch:Float):Void
	{
		if (tracks == null) return;
		#if FLX_PITCH
		for (track in tracks)
			if (track.sound != null) track.sound.pitch = pitch;
		#end
	}

	public static function setVolumeAll(tracks:Array<ExtraVocalTrack>, volume:Float):Void
	{
		if (tracks == null) return;
		for (track in tracks)
			if (track.sound != null) track.sound.volume = volume;
	}

	/** Mutes every stem bound to `side` (a miss on that strumline). */
	public static function muteSide(tracks:Array<ExtraVocalTrack>, side:String):Void
	{
		if (tracks == null) return;
		for (track in tracks)
			if (track.side == side && track.sound != null && track.sound.volume != 0)
				track.sound.volume = 0;
	}

	/** Restores every stem of `side` to `volume` (a hit on that strumline). */
	public static function unmuteSide(tracks:Array<ExtraVocalTrack>, side:String, volume:Float):Void
	{
		if (tracks == null) return;
		for (track in tracks)
			if (track.side == side && track.sound != null && track.sound.volume != volume)
				track.sound.volume = volume;
	}

	/**
	 * Re-applies the global vocal override to stems that are currently audible;
	 * a stem muted by a miss stays muted (same rule as the main stems).
	 */
	public static function enforceVolume(tracks:Array<ExtraVocalTrack>, volume:Float):Void
	{
		if (tracks == null) return;
		for (track in tracks)
			if (track.sound != null && track.sound.volume > 0 && track.sound.volume != volume)
				track.sound.volume = volume;
	}
}
