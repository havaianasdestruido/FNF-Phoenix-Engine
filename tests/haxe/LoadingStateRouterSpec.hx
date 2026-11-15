import backend.LowMemory;
import backend.MenuMusic;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxState;
import flixel.util.typeLimit.NextState;
import openfl.utils.Assets;
import play.PlayState;
import states.LoadingState;
import states.LoadingStateRouter;
import states.TitleState;

class RouterMenu extends FlxState
{
  public static var count:Int = 0;
  public var arg:String;
  public function new(arg:String = 'class-default') { super(); this.arg = arg; count++; }
}

class LoadingStateRouterSpec
{
  static var oldDestroyed:Bool = false;
  static function check(ok:Bool, message:String):Void { if (!ok) throw message; }
  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }

  static function main():Void
  {
    testInstanceAndClass();
    testFactoryAndReset();
    testTitle();
    testSongAndDirectLoading();
    #if NO_PRELOAD_ALL
    testNoPreloadProbe();
    #end
    trace('LoadingStateRouterSpec passed');
  }

  static function reset():Void
  {
    oldDestroyed = false;
    RouterMenu.count = PlayState.count = TitleState.count = 0;
    PlayState.SONG = null;
    LowMemory.experimental = false;
    Paths.probes = 0;
    MenuMusic.fadeCalls = 0;
    Assets.cache.loaded = Assets.libraries = false;
    FlxG.sound.music.stops = 0;
  }

  static function testInstanceAndClass():Void
  {
    reset();
    final existing = new RouterMenu('instance');
    final instanceRoute:NextState = LoadingStateRouter.route(existing, true, 'shared');
    check(instanceRoute.createInstance() == existing, 'an instance is returned unchanged');
    equal(RouterMenu.count, 1, 'instance routing never duplicates it');
    equal(FlxG.sound.music.stops, 1, 'stopMusic is honored for direct instance switches');

    reset();
    final classRoute:NextState = LoadingStateRouter.route(cast RouterMenu, false, 'shared');
    equal(RouterMenu.count, 0, 'class construction is deferred');
    oldDestroyed = true;
    final created:RouterMenu = cast classRoute.createInstance();
    equal(created.arg, 'class-default', 'class target is constructed');
    equal(RouterMenu.count, 1, 'class target is constructed once');
    final recreated:RouterMenu = cast classRoute.createInstance();
    check(created != recreated, 'class reset creates a fresh state');
    equal(RouterMenu.count, 2, 'class reset constructs exactly once');
  }

  static function testFactoryAndReset():Void
  {
    reset();
    final factory:NextState = function():FlxState
    {
      check(oldDestroyed, 'factory ran before the old state was destroyed');
      return new RouterMenu('kept argument');
    };
    final routed:NextState = LoadingStateRouter.route(factory, true, 'custom');
    equal(RouterMenu.count, 0, 'menu factory is deferred');
    equal(FlxG.sound.music.stops, 0, 'music is not stopped early for a deferred switch');
    oldDestroyed = true;
    final menu:RouterMenu = cast routed.createInstance();
    equal(menu.arg, 'kept argument', 'factory arguments survive routing');
    equal(RouterMenu.count, 1, 'factory produces one menu');
    equal(FlxG.sound.music.stops, 1, 'deferred direct switch stops music');
    final resetMenu:RouterMenu = cast routed.createInstance();
    check(resetMenu != menu && resetMenu.arg == menu.arg, 'reset reuses factory and its arguments');
  }

  static function testTitle():Void
  {
    reset();
    // A stale song should not change which target is routed to loading.
    PlayState.SONG = {song: 'previous', needsVoices: true};
    final routed:NextState = LoadingStateRouter.route(TitleState.new, false, 'shared');
    equal(TitleState.count, 0, 'title factory is deferred');
    oldDestroyed = true;
    final loader:LoadingState = cast routed.createInstance();
    check(Std.isOfType(loader, LoadingState), 'title uses the loading screen');
    equal(TitleState.count, 1, 'title constructed once');
    equal(MenuMusic.fadeCalls, 0, 'title does not trigger the song fade');
    final prepared = LoadingStateRouter.prepare(loader.target);
    check(Std.isOfType(prepared.preview, TitleState), 'loading queue can recognize title');
    check(prepared.target.createInstance() == prepared.preview, 'title preview is the state switched to');
    equal(TitleState.count, 1, 'inspecting the loader does not recreate title');
    check(Std.isOfType(prepared.target.createInstance(), TitleState), 'title reset constructs a new state');
    equal(TitleState.count, 2, 'title reset constructs once');
  }

  static function testSongAndDirectLoading():Void
  {
    reset();
    PlayState.SONG = {song: 'test', needsVoices: true};
    LowMemory.experimental = true;
    final target:NextState = function():FlxState
    {
      check(oldDestroyed, 'song factory ran before destruction');
      return new PlayState('song argument');
    };
    final routed:NextState = LoadingStateRouter.route(target, true, 'week1');
    equal(PlayState.count, 0, 'song factory is deferred');
    equal(MenuMusic.fadeCalls, 0, 'song fade waits for deferred target resolution');
    oldDestroyed = true;
    final loader:LoadingState = cast routed.createInstance();
    equal(MenuMusic.fadeCalls, 1, 'menu theme fades once when the song target is resolved');
    check(Std.isOfType(loader, LoadingState), 'song uses a loading screen');
    check(loader.stopMusic && loader.directory == 'week1', 'loader receives transition options');
    equal(PlayState.count, 1, 'router constructs the song once');
    final prepared = LoadingStateRouter.prepare(loader.target);
    final song:PlayState = cast prepared.preview;
    equal(song.marker, 'song argument', 'song constructor arguments are preserved');
    check(prepared.target.createInstance() == song, 'preview is reused at switch');
    equal(PlayState.count, 1, 'no second song before switch');
    final resetSong:PlayState = cast prepared.target.createInstance();
    check(resetSong != song && resetSong.marker == song.marker, 'song reset preserves its factory');
    equal(PlayState.count, 2, 'song reset constructs once');
    equal(Paths.probes, 0, 'experimental routing never decodes audio just to probe the cache');

    reset();
    oldDestroyed = true;
    // A caller can instantiate LoadingState directly with a target factory.
    final direct = new LoadingState(() -> new PlayState('direct'), false, 'shared');
    equal(PlayState.count, 0, 'direct loader construction leaves its target deferred');
    final directPrepared = LoadingStateRouter.prepare(direct.target);
    check(Std.isOfType(directPrepared.preview, PlayState), 'direct loader recognizes its target at create');
    check(directPrepared.target.createInstance() == directPrepared.preview, 'direct loader reuses its preview');
  }

  #if NO_PRELOAD_ALL
  static function testNoPreloadProbe():Void
  {
    reset();
    oldDestroyed = true;
    PlayState.SONG = {song: 'test', needsVoices: true};
    Assets.cache.loaded = Assets.libraries = true;
    var routed:NextState = LoadingStateRouter.route(() -> new PlayState(), false, 'shared');
    check(Std.isOfType(routed.createInstance(), PlayState), 'loaded normal song skips the screen');
    equal(MenuMusic.fadeCalls, 1, 'loaded song still triggers the menu-theme fade');
    equal(Paths.probes, 2, 'normal tier retains its instrumental and vocal probe');

    Paths.probes = 0;
    LowMemory.experimental = true;
    routed = LoadingStateRouter.route(() -> new PlayState(), false, 'shared');
    check(Std.isOfType(routed.createInstance(), LoadingState), 'experimental song uses loading screen without decoding probe');
    equal(Paths.probes, 0, 'experimental song does not run cache probes');

    Paths.probes = 0;
    routed = LoadingStateRouter.route(TitleState.new, false, 'shared');
    check(Std.isOfType(routed.createInstance(), TitleState), 'title retains the normal loaded-cache behavior');
    equal(Paths.probes, 2, 'experimental title does not suppress the old probe');
  }
  #end
}
