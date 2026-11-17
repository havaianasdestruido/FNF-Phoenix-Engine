import backend.MenuCheckerTextures;

/**
 * Renderer-free contract for the menu checker tile preference.
 * Run with: bash tests/haxe/run-menu-checker-textures.sh
 */
class MenuCheckerTexturesSpec
{
  static var failures:Int = 0;

  static function main():Void
  {
    preferenceNormalization();
    variantShape();
    folderListings();
    collectedMenuList();

    if (failures > 0) throw '$failures menu checker texture check(s) failed';
    trace('MenuCheckerTexturesSpec passed');
  }

  /* ------------------------------------------------------------------ *
   * The preference is a tile key; anything broken falls back to the
   * default tile so the menus always have something to repeat.
   * ------------------------------------------------------------------ */
  static function preferenceNormalization():Void
  {
    final T = MenuCheckerTextures;

    text(T.normalize('checker'), T.DEFAULT_KEY, 'the base tile is the default');
    text(T.normalize('checker_fatty'), 'checker_fatty', 'a shipped variant is kept');
    text(T.normalize(' Checker_Folk '), 'checker_folk', 'case and padding are normalized');
    text(T.normalize(null), T.DEFAULT_KEY, 'a missing value uses the default');
    text(T.normalize(''), T.DEFAULT_KEY, 'an empty value uses the default');
    text(T.normalize(7), T.DEFAULT_KEY, 'a non-string value uses the default');
    text(T.normalize('menuDesat'), T.DEFAULT_KEY, 'an unrelated asset is rejected');
    text(T.normalize('checkerX'), T.DEFAULT_KEY, 'a prefix without the separator is rejected');
    text(T.normalize('checker_'), T.DEFAULT_KEY, 'a variant with no name is rejected');
    text(T.normalize('../checker_fatty'), T.DEFAULT_KEY, 'a path is not a tile key');
  }

  /* ------------------------------------------------------------------ *
   * What counts as a tile key: the base tile or `checker_<name>`.
   * ------------------------------------------------------------------ */
  static function variantShape():Void
  {
    final T = MenuCheckerTextures;

    check(T.isVariant('checker'), 'the base tile is a variant of itself');
    check(T.isVariant('checker_logo'), 'a named variant is accepted');
    check(T.isVariant('checker_a_b'), 'a variant name may hold separators');
    check(!T.isVariant(null), 'no key at all is not a tile');
    check(!T.isVariant('checkerboard'), 'a longer word starting with the prefix is not a tile');
    check(!T.isVariant('checker_'), 'the separator alone is not a tile');
  }

  /* ------------------------------------------------------------------ *
   * Folder listings are read by file name, extension included.
   * ------------------------------------------------------------------ */
  static function folderListings():Void
  {
    final T = MenuCheckerTextures;

    text(T.keyFromFile('checker.png'), 'checker', 'the shipped tile');
    text(T.keyFromFile('checker_fatty.png'), 'checker_fatty', 'a shipped variant');
    text(T.keyFromFile('Checker_Lol.PNG'), 'checker_lol', 'file names are case-insensitive');
    text(T.keyFromFile('checker_sandbox.webp'), 'checker_sandbox', 'every loadable image extension counts');
    check(T.keyFromFile('menuDesat.png') == null, 'unrelated images are ignored');
    check(T.keyFromFile('checker') == null, 'a folder name without an extension is ignored');
    check(T.keyFromFile('checker_notes.xml') == null, 'sidecar files are ignored');
    check(T.keyFromFile(null) == null, 'a null entry is ignored');

    final keys:Array<String> = T.keysFromFiles([
      'checker_fatty.png', 'menuDesat.png', 'checker.png', 'checker_fatty.png', 'icons'
    ]);
    text(keys.join(','), 'checker,checker_fatty', 'listings are filtered, de-duplicated and sorted');
    check(T.keysFromFiles(null).length == 0, 'a missing listing is simply empty');
  }

  /* ------------------------------------------------------------------ *
   * The menu offers the shipped tiles plus whatever a folder adds.
   * ------------------------------------------------------------------ */
  static function collectedMenuList():Void
  {
    final T = MenuCheckerTextures;

    final shipped:Array<String> = T.collect(null);
    check(shipped.length == T.BUILT_IN.length, 'no listing means exactly the shipped tiles');
    text(shipped[0], T.DEFAULT_KEY, 'the default tile leads the list');
    check(shipped.indexOf('checker_lol') > -1, 'every shipped variant is offered');

    final withExtras:Array<String> = T.collect([['checker_sandbox.png', 'checker.png'], null, ['checker_logo.png']]);
    check(withExtras.length == T.BUILT_IN.length + 1, 'a new file adds one entry');
    text(withExtras[0], T.DEFAULT_KEY, 'the default tile still leads');
    check(withExtras.indexOf('checker_sandbox') > -1, 'the extra variant is offered');

    var sorted:Bool = true;
    for (i in 1...withExtras.length)
      if (withExtras[i - 1] > withExtras[i]) sorted = false;
    check(sorted, 'the offered list stays sorted');

    // A mod-added tile is still a valid preference, so it survives a save.
    text(T.normalize(withExtras[withExtras.length - 1]), withExtras[withExtras.length - 1],
      'an offered tile is always an acceptable preference');
  }

  static function text(actual:String, expected:String, message:String):Void
  {
    if (actual == expected) return;
    failures++;
    trace('FAIL: $message (expected $expected, got $actual)');
  }

  static function check(condition:Bool, message:String):Void
  {
    if (condition) return;
    failures++;
    trace('FAIL: $message');
  }
}
