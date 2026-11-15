import backend.ClientPrefs;
import backend.DiscordClient;
import backend.LowMemory;
import backend.MemoryProfiles;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import options.Option;

/** Exercises the production override/cleanup layer against small Flixel stubs. */
class LowMemorySpec
{
  static function main():Void
  {
    testProfileTransitionsAndSave();
    testCleanupPolicy();
    testSystemPressure();
    testImportedBaselineAndUntrustedFields();
    trace('LowMemorySpec passed');
  }

  static function testProfileTransitionsAndSave():Void
  {
    final original:Map<String, Dynamic> = playerValues();
    LowMemory.setProfile(MemoryProfiles.LOW, false);
    equal(ClientPrefs.maxSplashLimit, 4, 'Low applies first');
    equal(ClientPrefs.charsAndBG, true, 'Low does not suppress characters');

    LowMemory.setProfile('experimental', true);
    equal(ClientPrefs.memoryProfile, MemoryProfiles.EXPERIMENTAL, 'selection is canonical');
    check(ClientPrefs.lowMemoryMode, 'the legacy flag is on');
    check(ClientPrefs.downScroll, 'gameplay preferences are untouched');
    assertForced(MemoryProfiles.EXPERIMENTAL);
    check(!Main.fpsVar.visible, 'the FPS overlay is hidden immediately');
    check(!DiscordClient.isInitialized, 'Discord is shut down immediately');
    check(!FlxSprite.defaultAntialiasing, 'default antialiasing follows the profile');
    check(LowMemory.isManaged('cacheOnGPU'), 'the menu knows the GPU preference is forced');
    check(!LowMemory.isManaged('downScroll'), 'the menu leaves gameplay choices alone');
    var changes:Int = 0;
    final gpuOption = new Option('GPU cache', '', 'cacheOnGPU', 'bool', false);
    gpuOption.onChange = () -> changes++;
    gpuOption.setValue(false);
    gpuOption.change(); // BaseOptionsMenu still calls this after a blocked write.
    equal(ClientPrefs.cacheOnGPU, true, 'options cannot undo a forced value while the profile is active');
    equal(changes, 0, 'blocked option callbacks do not run side effects');
    final scrollOption = new Option('Scroll', '', 'downScroll', 'bool', true);
    scrollOption.onChange = () -> changes++;
    scrollOption.setValue(false);
    scrollOption.change();
    equal(ClientPrefs.downScroll, false, 'unmanaged options remain editable');
    equal(changes, 1, 'unmanaged callbacks still run');
    scrollOption.setValue(true);
    final actionOption = new Option('Action', '', 'freeMemoryNow', 'link', false);
    actionOption.onChange = () -> changes++;
    actionOption.setValue(true);
    actionOption.change();
    check(actionOption.getValue() == null, 'action options still carry no preference');
    equal(changes, 2, 'link actions still run');

    // The fake saveSettings uses the real begin/end-save window and records
    // precisely what would go to disk. New and shared overrides both restore.
    equal(ClientPrefs.savedProfile, MemoryProfiles.EXPERIMENTAL, 'the new profile persists');
    check(ClientPrefs.savedBaseline.length > 0, 'the saved profile keeps its snapshot');
    for (field => value in original)
      equal(ClientPrefs.savedValues.get(field), value, 'save preserves player choice for $field');
    assertForced(MemoryProfiles.EXPERIMENTAL);
    check(!DiscordClient.isInitialized && !Main.fpsVar.visible, 'save does not temporarily re-enable side effects');

    // Simulate a fresh load: disk contains player choices plus the snapshot.
    for (field => value in ClientPrefs.savedValues) Reflect.setField(ClientPrefs, field, value);
    ClientPrefs.memoryProfile = ClientPrefs.savedProfile;
    ClientPrefs.memoryProfileBaseline = ClientPrefs.savedBaseline;
    LowMemory.applyFromPrefs();
    assertForced(MemoryProfiles.EXPERIMENTAL);
    check(!Main.fpsVar.visible && !DiscordClient.isInitialized, 'restart reapplies runtime side effects');

    LowMemory.setProfile(MemoryProfiles.EXTREME, false);
    equal(ClientPrefs.charsAndBG, original.get('charsAndBG'), 'downgrading restores experimental-only choices');
    equal(ClientPrefs.cacheOnGPU, original.get('cacheOnGPU'), 'downgrading restores GPU caching');
    check(Main.fpsVar.visible && DiscordClient.isInitialized, 'downgrading restores overlay and Discord');
    check(!FlxSprite.defaultAntialiasing, 'Extreme still forces anti-aliasing off');
    assertForced(MemoryProfiles.EXTREME);

    LowMemory.setProfile(MemoryProfiles.OFF, false);
    for (field => value in original)
      equal(Reflect.field(ClientPrefs, field), value, 'Off restores the original value for $field');
    equal(ClientPrefs.memoryProfileBaseline, '', 'Off discards the snapshot');
    check(!ClientPrefs.lowMemoryMode, 'Off clears the legacy flag');
    check(FlxSprite.defaultAntialiasing && Main.fpsVar.visible, 'Off restores visuals');
  }

  static function testCleanupPolicy():Void
  {
    Paths.reset();
    FlxG.state = null;
    LowMemory.update(100);
    LowMemory.onSongEnd();
    LowMemory.onPlayStateExit();
    LowMemory.onFocusLost();
    equal(Paths.unused, 0, 'Off never triggers a profile cleanup');

    LowMemory.setProfile(MemoryProfiles.EXPERIMENTAL, false);
    Paths.reset(); // ignore the immediate cleanup on selection
    FlxG.state = new play.PlayState();
    LowMemory.update(100);
    FlxG.state = new states.LoadingState();
    LowMemory.update(100);
    @:privateAccess LowMemory.lastTrimAt = -1000;
    LowMemory.onFocusLost();
    equal(Paths.unused, 0, 'no idle or focus cleanup while loading can use a worker');
    FlxG.state = {};
    LowMemory.update(4.9);
    equal(Paths.unused, 0, 'not before the five-second interval');
    LowMemory.update(0.2);
    equal(Paths.unused, 1, 'five seconds in menus triggers a shallow cleanup');
    equal(Paths.stored, 0, 'live menus never receive a deep release');
    equal(Paths.compacted, 1, 'experimental compacts even if no asset was evicted');

    LowMemory.onSongEnd();
    equal(Paths.unused, 2, 'song end uses a shallow trim');
    equal(Paths.compacted, 2, 'song-end trim compacts');
    LowMemory.onPlayStateExit();
    equal(Paths.stored, 1, 'song teardown runs a deep release');
    equal(Paths.unused, 3, 'deep release follows with unused cleanup');
    equal(Paths.compacted, 3, 'song teardown compacts');

    @:privateAccess LowMemory.lastTrimAt = -1000;
    LowMemory.onFocusLost();
    LowMemory.onFocusLost();
    equal(Paths.unused, 4, 'rapid focus-loss signals are throttled');
    equal(Paths.compacted, 4, 'focus loss compacts once');

    LowMemory.setProfile(MemoryProfiles.EXTREME, false);
    Paths.reset();
    LowMemory.onPlayStateExit();
    equal(Paths.stored, 1, 'Extreme keeps its existing deep teardown');
    equal(Paths.unused, 1, 'Extreme still clears unused assets');
    equal(Paths.compacted, 0, 'Extreme does not force an extra heap compaction');
    LowMemory.setProfile(MemoryProfiles.OFF, false);
  }

  static function testSystemPressure():Void
  {
    LowMemory.setProfile(MemoryProfiles.OFF, false);
    Paths.reset();
    FlxG.state = new states.LoadingState();
    LowMemory.onSystemPressure();
    LowMemory.onSystemPressure(); // multiple events coalesce
    LowMemory.trim(true); // explicit requests must not race the worker either
    LowMemory.update(10);
    equal(Paths.unused, 0, 'pressure cleanup is deferred while loading');
    equal(Paths.stored, 0, 'no deep cleanup races a loading worker');

    FlxG.state = new play.PlayState();
    LowMemory.update(0.1);
    equal(Paths.unused, 1, 'deferred pressure drains once after loading');
    equal(Paths.stored, 0, 'the new live state receives only a shallow trim');
    LowMemory.update(0.1);
    equal(Paths.unused, 1, 'coalesced pressure does not repeat');
    LowMemory.onSystemPressure();
    equal(Paths.stored, 1, 'non-experimental profiles retain existing direct pressure behavior');
    equal(Paths.unused, 2, 'normal pressure follows the deep clear with unused cleanup');

    LowMemory.setProfile(MemoryProfiles.EXPERIMENTAL, false);
    Paths.reset();
    LowMemory.onSystemPressure();
    equal(Paths.stored, 0, 'experimental pressure does not reset live asset tracking');
    equal(Paths.unused, 1, 'experimental pressure trims unused assets');
    equal(Paths.compacted, 1, 'experimental pressure compacts');
    LowMemory.setProfile(MemoryProfiles.OFF, false);
  }

  static function testImportedBaselineAndUntrustedFields():Void
  {
    LowMemory.setProfile(MemoryProfiles.EXPERIMENTAL, false);
    // Settings import replaces the preferences wholesale, not the old snapshot.
    ClientPrefs.memoryProfile = MemoryProfiles.EXPERIMENTAL;
    ClientPrefs.charsAndBG = false;
    ClientPrefs.cacheOnGPU = false;
    ClientPrefs.showFPS = false;
    ClientPrefs.discordRPC = false;
    ClientPrefs.downScroll = true;
    LowMemory.reloadAfterImport();
    assertForced(MemoryProfiles.EXPERIMENTAL);
    LowMemory.setProfile(MemoryProfiles.OFF, false);
    equal(ClientPrefs.charsAndBG, false, 'Off restores the imported choice, not the pre-import snapshot');
    equal(ClientPrefs.cacheOnGPU, false, 'imported GPU choice is restored');
    equal(ClientPrefs.showFPS, false, 'imported FPS choice is restored');
    equal(ClientPrefs.discordRPC, false, 'imported Discord choice is restored');
    check(!Main.fpsVar.visible && !DiscordClient.isInitialized, 'import side effects follow restored choices');

    // A tampered internal snapshot cannot write unrelated gameplay settings.
    ClientPrefs.memoryProfile = MemoryProfiles.EXPERIMENTAL;
    ClientPrefs.memoryProfileBaseline = '{"profile":"Experimental Extreme","values":{"downScroll":false,"cacheOnGPU":false}}';
    ClientPrefs.downScroll = true;
    LowMemory.applyFromPrefs();
    check(ClientPrefs.downScroll, 'unmanaged fields in a baseline are ignored');
    LowMemory.setProfile(MemoryProfiles.OFF, false);
  }

  static function playerValues():Map<String, Dynamic>
  {
    final values:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (field in MemoryProfiles.managedKeys()) values.set(field, Reflect.field(ClientPrefs, field));
    return values;
  }

  static function assertForced(name:String):Void
  {
    for (field => value in MemoryProfiles.overrides(name))
      equal(Reflect.field(ClientPrefs, field), value, '$name forces $field');
  }

  static function check(value:Bool, message:String):Void
  {
    if (!value) throw message;
  }

  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }
}
