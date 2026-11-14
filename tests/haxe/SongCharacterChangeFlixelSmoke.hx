import backend.ClientPrefs;
import backend.LowMemory;
import backend.Paths;
import objects.Character;
import objects.Character.Boyfriend;
import play.PlayState;
import play.PlayState.StrumStub;
import play.helpers.PlayStateCharacterEvents;
import play.helpers.PlayStateScripts;

/** Real Flixel and production character/event code, with other engine objects stubbed. */
class SongCharacterChangeFlixelSmoke
{
  static function check(value:Bool, message:String):Void
  {
    if (!value) throw 'SongCharacterChangeFlixelSmoke: ' + message;
  }

  static function main():Void
  {
    Paths.files.set('characters/bf.json', '{"vocals_file":"bf","healthicon":"bf"}');
    Paths.files.set('characters/dad.json', '{"vocals_file":"dad","healthicon":"dad"}');
    Paths.files.set('characters/gf.json', '{"healthicon":"gf"}');
    Paths.files.set('characters/new-gf.json', '{"healthicon":"new-gf"}');
    Paths.files.set('characters/bf-alt.json', '{"healthicon":"bf-alt-icon"}');
    Paths.files.set('characters/rival.json', '{"vocals_file":"rival","noteskin":"pixel",'
      + '"health_drain":true,"drain_amount":0.05,"drain_floor":0.2,'
      + '"healthicon":"rival-icon","healthbar_colors":[4,5,6]}');
    Paths.files.set('characters/hero.json', '{"vocals_file":"hero","noteskin":"hero-skin",'
      + '"healthicon":"hero-icon","health_drain":true,"drain_amount":0.04,"drain_floor":0.3}');
    ClientPrefs.charsAndBG = false;
    LowMemory.experimental = true;
    final state = new PlayState();
    state.metadataOnlyCharacters = true;
    state.boyfriend = new Boyfriend(0, 0, 'bf', true);
    state.dad = new Character(0, 0, 'dad', false, false, true);
    state.gf = new Character(0, 0, 'gf', false, false, true);
    state.boyfriendGroup.add(state.boyfriend);
    state.dadGroup.add(state.dad);
    state.gfGroup.add(state.gf);
    final initialBf = state.boyfriend;
    state.boyfriendMap.set('bf', state.boyfriend);
    state.dadMap.set('dad', state.dad);
    state.gfMap.set('gf', state.gf);
    state.boyfriendGroup.visible = state.dadGroup.visible = state.gfGroup.visible = false;
    state.boyfriendGroup.active = state.dadGroup.active = state.gfGroup.active = false;
    final player = state.strumLineNotes.add(new StrumStub(1));
    final opponent = state.strumLineNotes.add(new StrumStub(0));

    // Numeric and named selectors must agree with the actual runtime event.
    check(PlayStateCharacterEvents.characterType('0') == 0, 'zero selects the player');
    check(PlayStateCharacterEvents.characterType('1') == 1, 'one selects the opponent');
    check(PlayStateCharacterEvents.characterType('2') == 2, 'two selects the girlfriend');
    check(PlayStateCharacterEvents.characterType(' Dad ') == 1, 'named selectors ignore case and whitespace');
    PlayStateCharacterEvents.record(state, 2000, '1', 'rival');
    PlayStateCharacterEvents.record(state, 1000, '0', 'hero');
    PlayStateCharacterEvents.record(state, 2000, 'gf', 'new-gf');
    check(state.charChangeNames.join(',') == 'hero,rival,new-gf', 'events from different sources are sorted stably');
    check(state.charChangeTypes.join(',') == '0,1,2', 'event names and roles remain aligned');

    PlayStateCharacterEvents.precache(state, '1', 'rival');
    PlayStateCharacterEvents.precache(state, '0', 'hero');
    PlayStateCharacterEvents.precache(state, 'gf', 'new-gf');
    final rival = state.dadMap.get('rival');
    check(rival != null && rival.width == 1 && rival.noteskin == 'pixel', 'precached opponent is metadata-only');
    check(state.boyfriendMap.get('hero').width == 1, 'precached player is metadata-only');
    check(state.gfMap.get('new-gf').width == 1, 'precached GF is metadata-only');
    check(Paths.atlasCalls == 0 && PlayStateScripts.unsupportedCharacterCalls == 0,
      'no character atlas or character script is loaded');

    PlayStateCharacterEvents.trigger(state, '1', 'rival');
    check(state.dad == rival && state.dad.animation != null, 'a live stand-in is reused after the change');
    check(PlayState.shouldDrainHealth && state.healthDrainAmount == 0.05 && state.healthDrainFloor == 0.2,
      'opponent health-drain behavior changes');
    check(state.dadNoteskin == 'pixel' && opponent.skin == 'pixel', 'opponent noteskin reaches the strum');
    check(state.iconP2.current == 'rival-icon' && state.scriptNames.get('dadName') == 'rival',
      'HUD icon and script name follow the character');
    PlayStateCharacterEvents.trigger(state, '2', 'new-gf');
    check(state.gf == state.gfMap.get('new-gf') && state.scriptNames.get('gfName') == 'new-gf',
      'girlfriend changes retain a live invisible stand-in and script name');
    check(!state.gfGroup.visible && !state.gfGroup.active, 'changing GF never reveals the invisible group');

    PlayState.opponentChart = true;
    PlayStateCharacterEvents.trigger(state, '0', 'hero');
    check(PlayState.shouldDrainHealth && state.healthDrainAmount == 0.04 && state.healthDrainFloor == 0.3,
      'opponent-chart health drain follows the player character');
    check(state.bfNoteskin == 'hero-skin' && player.skin == 'hero-skin', 'player noteskin reaches the strum');
    check(state.iconP1.current == 'hero-icon', 'player icon changes');
    PlayStateCharacterEvents.trigger(state, '0', 'bf');
    check(state.boyfriend == initialBf, 'returning to BF reuses the original stand-in');
    check(state.iconP1.current == 'bf' && state.bfNoteskin == '', 'returning to BF restores icon and default skin');
    check(!PlayState.shouldDrainHealth, 'health drain is disabled when the new character does not use it');
    check(Paths.atlasCalls == 0 && PlayStateScripts.unsupportedCharacterCalls == 0, 'on-demand change also skips art and scripts');

    PlayState.isPixelStage = true;
    Paths.missingSkinFiles.set('images/pixelUI/noteskins/hero-skinENDS.png', true);
    PlayStateCharacterEvents.trigger(state, '0', 'hero');
    check(state.bfNoteskin == '' && player.skin == '', 'incomplete pixel skin restores the chart receptor skin');
    Paths.missingSkinFiles.clear();
    PlayStateCharacterEvents.trigger(state, '0', 'bf');
    PlayStateCharacterEvents.trigger(state, '0', 'hero');
    check(state.bfNoteskin == 'hero-skin' && player.skin == 'hero-skin', 'complete pixel skin reaches the receptor');
    PlayState.isPixelStage = false;

    // Simulate a song created with the pre-existing manual HUD-only setting.
    // Even if a preference changes, its character groups were already retired.
    LowMemory.experimental = false;
    state.metadataOnlyCharacters = false;
    state.songCharacterVisuals = false;
    ClientPrefs.charsAndBG = true;
    PlayStateCharacterEvents.precache(state, '1', 'manual-disabled');
    PlayStateCharacterEvents.trigger(state, '1', 'manual-disabled');
    check(!state.dadMap.exists('manual-disabled') && state.dad == rival,
      'a manual HUD-only song cannot resurrect its retired character groups');

    // A normally created song keeps processing character events even if a
    // profile subsequently forces the live preference off.
    state.songCharacterVisuals = true;
    ClientPrefs.charsAndBG = false;
    final altBf = new Boyfriend(0, 0, 'bf-alt', true);
    state.boyfriendMap.set('bf-alt', altBf);
    state.boyfriendGroup.add(altBf);
    ClientPrefs.bfIconStyle = 'Default';
    PlayStateCharacterEvents.trigger(state, '0', 'bf-alt');
    check(state.iconP1.current == 'bf-alt-icon', 'normal default BF style uses the character health icon');
    ClientPrefs.bfIconStyle = 'VS Nonsense V2';
    PlayStateCharacterEvents.trigger(state, '0', 'bf');
    check(state.iconP1.current == 'bfnonsense', 'normal custom BF style still overrides the icon');

    state.boyfriendGroup.destroy();
    state.dadGroup.destroy();
    state.gfGroup.destroy();
    state.strumLineNotes.destroy();
    state.notes.destroy();
    state.sustainNotes.destroy();
    check(rival.animation == null, 'stand-ins are destroyed with their groups');
    trace('SongCharacterChangeFlixelSmoke passed');
  }
}
