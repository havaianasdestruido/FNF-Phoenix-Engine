import backend.PlatformIcons;
import backend.PlatformSupport;

/**
 * Contract tests for `backend.PlatformSupport`.
 *
 * The module is Flixel-free on purpose, so this spec runs in the Haxe
 * interpreter with nothing but the compiler. The runner executes it once per
 * target define; every run asserts that the tags, aliases, negation and the
 * `ClientPrefs`/`pack.json` registries agree with the build being emulated.
 *
 *     bash tests/haxe/run-platform-support.sh
 */
class PlatformSupportSpec
{
  /**
   * A real game target defines one of these; the bare interpreter run (used to
   * exercise the `sys` fallback) defines none, so it only gets the generic
   * assertions below.
   */
  static inline var HAS_TARGET:Bool = #if (windows || mac || linux || android || ios || html5 || air || flash) true #else false #end;

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    targetTags();
    requirementLists();
    aliasesAndUnknownTags();
    preferenceRegistry();
    packRequirements();
    bundledMods();
    trace('PlatformSupportSpec: ok (' + PlatformSupport.describeCurrent() + ')');
  }

  /** Family and capability tags must follow the build, not the build host. */
  static function targetTags():Void
  {
    final kind:PlatformKind = PlatformIcons.detect();
    final tags:Array<String> = PlatformSupport.currentTags();
    check(tags.length > 0, 'current tags are never empty');

    // The concrete target tag is always present.
    equal(PlatformSupport.supports([Std.string(kind)]), true, 'own target tag is present');

    // The bare interpreter run has no target define; only a real build can
    // be asked about families and capabilities.
    if (!HAS_TARGET) return;

    // Families.
    final desktop:Bool = kind == PlatformKind.WINDOWS || kind == PlatformKind.MAC || kind == PlatformKind.LINUX;
    final mobile:Bool = kind == PlatformKind.ANDROID || kind == PlatformKind.IOS;
    equal(PlatformSupport.supports([PlatformSupport.DESKTOP]), desktop, 'desktop family');
    equal(PlatformSupport.supports([PlatformSupport.MOBILE]), mobile, 'mobile family');
    equal(PlatformSupport.supports([PlatformSupport.APPLE]), kind == PlatformKind.MAC || kind == PlatformKind.IOS, 'apple family');

    // AIR and Flash are *not* native desktops: a `desktop` requirement must not
    // leak the window effects into them.
    if (kind == PlatformKind.AIR || kind == PlatformKind.FLASH)
      equal(PlatformSupport.supports([PlatformSupport.DESKTOP]), false, 'flash/air is not native desktop');
    if (kind == PlatformKind.WEB)
      equal(PlatformSupport.supports([PlatformSupport.DESKTOP]), false, 'web is not native desktop');

    // Capabilities.
    equal(PlatformSupport.supports([PlatformSupport.WINDOW_COLOR_KEY]), kind == PlatformKind.WINDOWS, 'color-key transparency');
    equal(PlatformSupport.supports([PlatformSupport.WINDOW_CLICK_THROUGH]), kind == PlatformKind.WINDOWS, 'click-through');
    equal(PlatformSupport.supports([PlatformSupport.WINDOW_ALPHA]), desktop, 'window alpha');
    equal(PlatformSupport.supports([PlatformSupport.SCREEN_RESOLUTION]), desktop, 'resolution picker');
    equal(PlatformSupport.supports([PlatformSupport.DESKTOP_NOTIFICATIONS]), desktop, 'desktop notifications');
    equal(PlatformSupport.supports([PlatformSupport.VIDEO_RENDER]), desktop || kind == PlatformKind.ANDROID, 'game renderer');

    // Lime's FileDialog is desktop-only; Android reaches the SAF picker via JNI.
    final filePicker:Bool = desktop || kind == PlatformKind.ANDROID;
    equal(PlatformSupport.supports([PlatformSupport.FILE_PICKER]), filePicker, 'file picker');
    equal(PlatformSupport.supports([PlatformSupport.FILESYSTEM]), desktop || mobile, 'filesystem');

    // Deeplinks exist on Windows (runtime registration) and Android (manifest).
    equal(PlatformSupport.supports([PlatformSupport.DEEPLINK]), kind == PlatformKind.WINDOWS || kind == PlatformKind.ANDROID, 'deeplink');
  }

  /** AND lists, negation, empty lists. */
  static function requirementLists():Void
  {
    equal(PlatformSupport.supports(null), true, 'null requirements');
    equal(PlatformSupport.supports([]), true, 'empty requirements');
    equal(PlatformSupport.supports(['']), true, 'blank requirement');

    // Manifests may opt in to "this works everywhere" instead of omitting the
    // field. All four spellings must behave like null/[].
    for (wildcard in ['all', 'any', '*', 'everywhere'])
      equal(PlatformSupport.supports([wildcard]), true, 'wildcard "$wildcard" matches everywhere');
    equal(PlatformSupport.supports(['all', '!mobile']), !PlatformSupport.supports(['mobile']),
      'wildcard still honours exclusions');
    equal(PlatformSupport.supports(['!all']), false, 'excluding everything can never match');

    equal(PlatformSupport.supports(['!mobile']), !PlatformSupport.supports(['mobile']), 'negation mirrors the positive tag');

    // Every exclusion has to hold.
    equal(PlatformSupport.supports(['!mobile', '!web']),
      !PlatformSupport.supports(['mobile']) && !PlatformSupport.supports(['web']), 'all exclusions must hold');

    // Positive entries are alternatives: a list that names several targets
    // matches when any one of them is this build.
    final current:String = Std.string(PlatformIcons.detect());
    final other:String = current == PlatformKind.WINDOWS ? PlatformKind.MAC : PlatformKind.WINDOWS;
    equal(PlatformSupport.supports([current, other]), true, 'positive list is an OR list');
    equal(PlatformSupport.supports([current, '!dreamcast']), PlatformSupport.supports([current]), 'alternatives combine with exclusions');
    equal(PlatformSupport.supports([current, '!mobile']),
      PlatformSupport.supports([current]) && !PlatformSupport.supports(['mobile']), 'exclusion still applies');

    // "desktop or android" is the Game Renderer case: never both at once.
    final renderTargets:Array<String> = [PlatformSupport.DESKTOP, PlatformSupport.ANDROID];
    equal(PlatformSupport.supports(renderTargets), PlatformSupport.supports([PlatformSupport.DESKTOP])
      || PlatformSupport.supports([PlatformSupport.ANDROID]), 'desktop-or-android');
  }

  /** Aliases resolve to the canonical tag; typos must not match. */
  static function aliasesAndUnknownTags():Void
  {
    equal(PlatformSupport.canonicalTag('win'), PlatformSupport.WINDOWS, 'win alias');
    equal(PlatformSupport.canonicalTag('Win32'), PlatformSupport.WINDOWS, 'Win32 alias');
    equal(PlatformSupport.canonicalTag('osx'), PlatformSupport.MAC, 'osx alias');
    equal(PlatformSupport.canonicalTag('darwin'), PlatformSupport.MAC, 'darwin alias');
    equal(PlatformSupport.canonicalTag('html5'), PlatformSupport.WEB, 'html5 alias');
    equal(PlatformSupport.canonicalTag('js'), PlatformSupport.WEB, 'js alias');
    equal(PlatformSupport.canonicalTag('iphone'), PlatformSupport.IOS, 'iphone alias');
    equal(PlatformSupport.canonicalTag('phone'), PlatformSupport.MOBILE, 'phone alias');
    equal(PlatformSupport.canonicalTag('cpp'), PlatformSupport.NATIVE, 'cpp alias');

    check(PlatformSupport.isKnownTag('desktop'), 'desktop is known');
    check(PlatformSupport.isKnownTag('!mobile'), 'negated tag is known');
    check(PlatformSupport.isKnownTag('window-alpha'), 'capability tag is known');
    check(PlatformSupport.isKnownTag('all'), 'wildcard all is known');
    equal(PlatformSupport.canonicalTag('*'), PlatformSupport.ALL, '* alias');
    equal(PlatformSupport.canonicalTag('everywhere'), PlatformSupport.ALL, 'everywhere alias');
    check(!PlatformSupport.isKnownTag('dreamcast'), 'unknown tag is rejected');
    check(!PlatformSupport.isKnownTag(null), 'null tag is rejected');

    equal(PlatformSupport.supports(['dreamcast']), false, 'unknown tag never matches');
    equal(PlatformSupport.supports(['!dreamcast']), true, 'negated unknown tag matches');
  }

  /** `ClientPrefs` fields only follow platforms that can use them. */
  static function preferenceRegistry():Void
  {
    final cutout:Array<String> = PlatformSupport.requirementsForPreference('respectCutout');
    equal(cutout.length, 1, 'cut-out has one requirement');
    equal(cutout[0], PlatformSupport.ANDROID, 'cut-out is Android-only');
    equal(PlatformSupport.supportsPreference('respectCutout'), PlatformIcons.detect() == PlatformKind.ANDROID, 'cut-out support');

    equal(PlatformSupport.supportsPreference('androidNotifications'), PlatformIcons.detect() == PlatformKind.ANDROID, 'notifications support');
    equal(PlatformSupport.supportsPreference('mobileCAlpha'), PlatformSupport.supports([PlatformSupport.MOBILE]), 'mobile controls');
    equal(PlatformSupport.supportsPreference('hitboxType'), PlatformSupport.supports([PlatformSupport.MOBILE]), 'hitbox');
    equal(PlatformSupport.supportsPreference('ffmpegMode'), PlatformSupport.supports([PlatformSupport.VIDEO_RENDER]), 'renderer options');
    equal(PlatformSupport.supportsPreference('autosaveCharts'), PlatformSupport.supports([PlatformSupport.FILESYSTEM]), 'chart autosave');
    equal(PlatformSupport.supportsPreference('deeplinkEnabled'), PlatformSupport.supports([PlatformSupport.DEEPLINK]), 'deeplink toggle');

    // Normal settings apply everywhere.
    equal(PlatformSupport.requirementsForPreference('downScroll'), null, 'normal pref has no platform requirement');
    equal(PlatformSupport.supportsPreference('downScroll'), true, 'normal pref works everywhere');
    equal(PlatformSupport.requirementsForPreference(null), null, 'null field');
  }

  /** `pack.json` `platforms` accepts an array or a string. */
  static function packRequirements():Void
  {
    equal(PlatformSupport.requirementsForPack(null), null, 'null pack');

    final arrayPack:Dynamic = {name: 'Test', platforms: ['desktop', '!air']};
    final fromArray:Array<String> = PlatformSupport.requirementsForPack(arrayPack);
    equal(fromArray.length, 2, 'array length');
    equal(fromArray[0], 'desktop', 'array entry 1');
    equal(fromArray[1], '!air', 'array entry 2');
    equal(PlatformSupport.supports(fromArray), PlatformSupport.supports([PlatformSupport.DESKTOP]), 'array requirements');

    final stringPack:Dynamic = {platforms: 'windows, linux'};
    final fromString:Array<String> = PlatformSupport.requirementsForPack(stringPack);
    equal(fromString.length, 2, 'string split length');
    equal(PlatformSupport.supports(fromString), PlatformIcons.detect() == PlatformKind.WINDOWS
      || PlatformIcons.detect() == PlatformKind.LINUX, 'string requirements');

    final noField:Dynamic = {name: 'Test'};
    equal(PlatformSupport.requirementsForPack(noField), null, 'pack without platforms');

    final badField:Dynamic = {platforms: 42};
    equal(PlatformSupport.requirementsForPack(badField), null, 'non-list platforms is ignored');

    final emptyArray:Dynamic = {platforms: []};
    equal(PlatformSupport.requirementsForPack(emptyArray), null, 'empty platforms means everywhere');

    // Backwards compatibility contract: mods written before the field existed
    // (and mods with no pack.json at all) keep loading on every target.
    equal(PlatformSupport.supportsPack(null), true, 'mod without a pack.json loads everywhere');
    equal(PlatformSupport.supportsPack({}), true, 'empty pack loads everywhere');
    equal(PlatformSupport.supportsPack(noField), true, 'pack without platforms loads everywhere');
    equal(PlatformSupport.supportsPack(emptyArray), true, 'empty platforms loads everywhere');
    equal(PlatformSupport.supportsPack(badField), true, 'non-list platforms is ignored');
    equal(PlatformSupport.supportsPack({platforms: ['all']}), true, 'explicit all loads everywhere');
    equal(PlatformSupport.supportsPack({platforms: ['any']}), true, 'explicit any loads everywhere');
    equal(PlatformSupport.supportsPack({platforms: ['desktop']}), PlatformSupport.supports([PlatformSupport.DESKTOP]),
      'specific platforms still filter');

    // Requested exclusions survive the wildcard: only the desktop build is filtered.
    equal(PlatformSupport.supportsPack({platforms: ['all', '!mobile']}), !PlatformSupport.supports(['mobile']),
      'wildcard plus exclusion');
  }

  /**
   * The bundled transparency demo must stay desktop-only. Its `pack.json` is
   * what `Mods.parseList()` reads at runtime, and `BUNDLED_MOD_PLATFORMS` in
   * `project.hxp` mirrors it for packaging.
   */
  static function bundledMods():Void
  {
    #if sys
    final path:String = 'mods/transparency-test/pack.json';
    if (!sys.FileSystem.exists(path)) return; // spec copied out of the repo

    final pack:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
    final requirements:Array<String> = PlatformSupport.requirementsForPack(pack);
    check(requirements != null, 'transparency-test declares platforms');
    equal(PlatformSupport.supports(requirements), PlatformSupport.supports([PlatformSupport.DESKTOP]), 'transparency-test is desktop-only');
    #end
  }
}
