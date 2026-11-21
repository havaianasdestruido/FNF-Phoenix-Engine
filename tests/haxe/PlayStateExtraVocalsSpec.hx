import backend.ClientPrefs;
import backend.Paths;
import data.ExtraVocals;
import flixel.FlxG;
import play.helpers.PlayStateExtraVocals;

/**
 * Renderer-free tests for the extra vocal stems runtime
 * ("unlimited vocals per strumline", docs/EXTRA_VOCALS.md).
 *
 * Run with tests/haxe/run-extra-vocals.sh. The runner compiles the real
 * source/play/helpers/PlayStateExtraVocals.hx and source/data/ExtraVocals.hx
 * against the stubs in tests/haxe/stubs/extra-vocals/, so these assertions
 * exercise production code, not a reimplementation.
 */
class PlayStateExtraVocalsSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	static function reset():Void
	{
		Paths.existing.clear();
		FlxG.sound.list.members = [];
		FlxG.sound.music = null;
		FlxG.log.messages = [];
		ClientPrefs.extraVocals = true;
	}

	static function main():Void
	{
		testLoadDisabled();
		testLoadStems();
		testLoadSkipsMissing();
		testLoadWithoutVoices();
		testMuteSides();
		testPlaybackOps();
		testFindAndNames();
		testDispose();
		trace('PlayStateExtraVocalsSpec passed');
	}

	static function testLoadDisabled():Void
	{
		reset();
		ClientPrefs.extraVocals = false;
		Paths.existing.set('song/Voices-GF', true);
		final tracks = PlayStateExtraVocals.load([{file: 'GF'}], 'song', 'hard', false);
		equal(tracks.length, 0, 'the Extra Vocal Stems option gates loading');
		equal(FlxG.sound.list.members.length, 0, 'nothing is registered when disabled');
	}

	static function testLoadStems():Void
	{
		reset();
		Paths.existing.set('song/Voices-GF', true);
		Paths.existing.set('song/Voices-Choir-hard', true); // difficulty variant wins
		Paths.existing.set('song/Voices-Choir', true);
		final tracks = PlayStateExtraVocals.load([
			{name: 'gf', file: 'GF', side: 'none'},
			{file: 'Choir', side: 'opponent'}
		], 'song', 'hard', false);
		equal(tracks.length, 2, 'both stems loaded');
		equal(tracks[0].name, 'gf', 'chart name kept');
		equal(tracks[0].sound.loaded, 'song/Voices-GF', 'plain stem file resolved');
		equal(tracks[1].sound.loaded, 'song/Voices-Choir-hard', 'difficulty stem variant wins');
		equal(FlxG.sound.list.members.length, 2, 'stems join the global sound list');
	}

	static function testLoadSkipsMissing():Void
	{
		reset();
		Paths.existing.set('song/Voices-GF', true);
		final tracks = PlayStateExtraVocals.load([{file: 'GF'}, {file: 'Missing'}], 'song', '', false);
		equal(tracks.length, 1, 'missing stem files are skipped');
		check(FlxG.log.messages.length == 1, 'a skipped stem is logged');
	}

	static function testLoadWithoutVoices():Void
	{
		reset();
		// PlayState passes null when the chart says needsVoices is false.
		final tracks = PlayStateExtraVocals.load(null, 'song', '', false);
		equal(tracks.length, 0, 'no field means no stems');
	}

	static function testMuteSides():Void
	{
		reset();
		Paths.existing.set('song/Voices-A', true);
		Paths.existing.set('song/Voices-B', true);
		Paths.existing.set('song/Voices-C', true);
		final tracks = PlayStateExtraVocals.load([
			{file: 'A', side: 'player'},
			{file: 'B', side: 'opponent'},
			{file: 'C', side: 'none'}
		], 'song', '', false);

		PlayStateExtraVocals.muteSide(tracks, ExtraVocals.playedSide(false));
		equal(tracks[0].sound.volume, 0, 'player-side stem mutes on a player miss');
		equal(tracks[1].sound.volume, 1, 'opponent-side stem survives a player miss');
		equal(tracks[2].sound.volume, 1, 'sideless stem survives a player miss');

		PlayStateExtraVocals.muteSide(tracks, ExtraVocals.playedSide(true));
		equal(tracks[1].sound.volume, 0, 'opponent-side stem mutes on an opponent-chart miss');

		PlayStateExtraVocals.unmuteSide(tracks, ExtraVocals.playedSide(false), 0.7);
		equal(tracks[0].sound.volume, 0.7, 'player-side stem unmutes to the override volume on hit');
		equal(tracks[1].sound.volume, 0, 'opponent-side stem stays muted until its own side hits');

		PlayStateExtraVocals.unmuteSide(tracks, ExtraVocals.playedSide(true), 0.7);
		equal(tracks[1].sound.volume, 0.7, 'opponent-side stem unmutes on an opponent hit');
		equal(tracks[2].sound.volume, 1, 'sideless stem is never touched');
	}

	static function testPlaybackOps():Void
	{
		reset();
		Paths.existing.set('song/Voices-A', true);
		Paths.existing.set('song/Voices-B', true);
		final tracks = PlayStateExtraVocals.load([{file: 'A'}, {file: 'B'}], 'song', '', false);

		PlayStateExtraVocals.playAll(tracks);
		check(tracks[0].sound.playing && tracks[1].sound.playing, 'playAll starts every stem');

		PlayStateExtraVocals.pauseAll(tracks);
		check(!tracks[0].sound.playing && !tracks[1].sound.playing, 'pauseAll pauses every stem');

		PlayStateExtraVocals.resumeAll(tracks);
		check(tracks[0].sound.playing && tracks[1].sound.playing, 'resumeAll resumes every stem');

		PlayStateExtraVocals.setTimeAll(tracks, 250);
		equal(tracks[0].sound.time, 250, 'setTimeAll seeks every stem');
		equal(tracks[1].sound.time, 250, 'setTimeAll seeks every stem');

		PlayStateExtraVocals.setPitchAll(tracks, 1.5);
		equal(tracks[0].sound.pitch, 1.5, 'setPitchAll repitches every stem');

		PlayStateExtraVocals.setVolumeAll(tracks, 0.4);
		equal(tracks[0].sound.volume, 0.4, 'setVolumeAll covers every stem');

		tracks[0].sound.volume = 0;
		tracks[1].sound.volume = 1;
		PlayStateExtraVocals.enforceVolume(tracks, 0.6);
		equal(tracks[0].sound.volume, 0, 'enforceVolume leaves miss-muted stems alone');
		equal(tracks[1].sound.volume, 0.6, 'enforceVolume forces audible stems to the override');

		PlayStateExtraVocals.stopAll(tracks);
		check(!tracks[0].sound.playing && tracks[0].sound.time == 0, 'stopAll stops every stem');

		// Empty/null lists (the common case) must be free and safe.
		PlayStateExtraVocals.playAll([]);
		PlayStateExtraVocals.pauseAll([]);
		PlayStateExtraVocals.setTimeAll(null, 0);
		PlayStateExtraVocals.setVolumeAll(null, 1);
		PlayStateExtraVocals.muteSide(null, ExtraVocals.SIDE_PLAYER);
		check(true, 'empty track lists are no-ops');
	}

	static function testFindAndNames():Void
	{
		reset();
		Paths.existing.set('song/Voices-A', true);
		Paths.existing.set('song/Voices-B', true);
		final tracks = PlayStateExtraVocals.load([{name: 'lead', file: 'A'}, {name: 'choir', file: 'B'}], 'song', '', false);
		equal(PlayStateExtraVocals.names(tracks).join(','), 'lead,choir', 'names come back in chart order');
		check(PlayStateExtraVocals.find(tracks, 'choir') == tracks[1], 'find resolves a stem by name');
		equal(PlayStateExtraVocals.find(tracks, 'nope'), null, 'find misses cleanly');
		equal(PlayStateExtraVocals.names(null).length, 0, 'names of nothing is nothing');
	}

	static function testDispose():Void
	{
		reset();
		Paths.existing.set('song/Voices-A', true);
		final tracks = PlayStateExtraVocals.load([{file: 'A'}], 'song', '', false);
		final sound = tracks[0].sound;
		PlayStateExtraVocals.dispose(tracks);
		equal(tracks.length, 0, 'dispose empties the track list');
		check(sound.destroyed, 'dispose destroys the sound');
		equal(FlxG.sound.list.members.length, 0, 'dispose unregisters the sound');
		PlayStateExtraVocals.dispose(tracks);
		check(true, 'dispose is idempotent');
	}
}
