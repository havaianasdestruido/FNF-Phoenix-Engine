package backend;

using StringTools;

/**
 * Renderer-free rules behind `ClientPrefs.menuCheckerTexture`
 * (Super Secret Debug Menu -> Menu Checker Texture).
 *
 * Every menu backdrop repeats one shared 120x120 tile (`images/checker.png`)
 * through `objects.MovingCheckerboard`. The engine ships a few alternative
 * tiles of the same size (`images/checker_fatty.png`, ...), so switching
 * between them is only a matter of picking a key: the file name without its
 * extension.
 *
 * No Flixel, OpenFL or Lime imports, so `tests/haxe/MenuCheckerTexturesSpec.hx`
 * can interpret this module without the game's haxelibs -- the same trick
 * `backend.MenuMusicLogic` uses for the menu music rules. Looking the tiles up
 * on disk stays in `objects.MovingCheckerboard.availableTextures()`.
 */
class MenuCheckerTextures
{
  /** Tile every menu repeats when the preference is missing or invalid. */
  public static inline var DEFAULT_KEY:String = 'checker';

  /** Every tile key starts with this; a variant appends `_name`. */
  public static inline var PREFIX:String = 'checker';

  /** Separator between the prefix and a variant's name. */
  public static inline var SEPARATOR:String = '_';

  /** The `images/checker*.png` tiles shipped in `assets/preload/images/`. */
  public static final BUILT_IN:Array<String> = [
    'checker', 'checker_fatty', 'checker_folk', 'checker_logo', 'checker_lol'
  ];

  /** Image extensions `backend.Paths` can load, used to read a folder listing. */
  public static final IMAGE_EXTENSIONS:Array<String> = ['png', 'jpg', 'jpeg', 'webp'];

  /**
   * The tile key a preference asks for.
   *
   * Anything else -- a missing value, a non-string, a hand-edited save, a name
   * that is not `checker` or `checker_*` -- falls back to `DEFAULT_KEY`, so a
   * corrupt save can never point every menu at a texture that does not exist.
   */
  public static function normalize(pref:Dynamic):String
  {
    if (!Std.isOfType(pref, String)) return DEFAULT_KEY;
    final key:String = (pref:String).trim().toLowerCase();
    return isVariant(key) ? key : DEFAULT_KEY;
  }

  /** True when `key` names the base tile or one of its `checker_*` variants. */
  public static function isVariant(key:String):Bool
  {
    if (key == null) return false;
    if (key.length <= PREFIX.length) return key == PREFIX;
    if (!key.startsWith(PREFIX)) return false;
    // `checker_` on its own is not a tile: a variant needs a name.
    return key.charAt(PREFIX.length) == SEPARATOR && key.length > PREFIX.length + SEPARATOR.length;
  }

  /**
   * Tile key inside a folder-listing entry, or `null` when the entry is not a
   * checker image (`menuDesat.png`, a sub-folder, a sidecar `.xml`, ...).
   */
  public static function keyFromFile(entry:String):Null<String>
  {
    if (entry == null) return null;
    final name:String = entry.trim().toLowerCase();
    for (extension in IMAGE_EXTENSIONS)
    {
      final suffix:String = '.$extension';
      if (!name.endsWith(suffix)) continue;
      final key:String = name.substr(0, name.length - suffix.length);
      return isVariant(key) ? key : null;
    }
    return null;
  }

  /** Sorted, de-duplicated tile keys from one folder listing. */
  public static function keysFromFiles(entries:Array<String>):Array<String>
  {
    final keys:Array<String> = [];
    if (entries != null)
      for (entry in entries)
      {
        final key:Null<String> = keyFromFile(entry);
        if (key != null && keys.indexOf(key) < 0) keys.push(key);
      }
    keys.sort(compare);
    return keys;
  }

  /**
   * Every tile the menu can offer: the shipped ones plus whatever `listings`
   * (folder listings of the preload images folder) add, so a `checker_*.png`
   * a content update drops in reaches the debug menu without a code change.
   */
  public static function collect(listings:Array<Array<String>>):Array<String>
  {
    final keys:Array<String> = BUILT_IN.copy();
    if (listings != null)
      for (listing in listings)
        for (key in keysFromFiles(listing))
          if (keys.indexOf(key) < 0) keys.push(key);
    keys.sort(compare);
    return keys;
  }

  /** Alphabetical order; the base tile sorts ahead of every variant. */
  static function compare(a:String, b:String):Int
  {
    return a < b ? -1 : (a > b ? 1 : 0);
  }
}
