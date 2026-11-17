package backend;

import backend.FreeplayFilter;
import flixel.util.FlxSave;

/**
 * Loads and saves the Freeplay filter page state.
 *
 * Deliberately a save of its own (`freeplay_filter`) instead of more fields on
 * the monolithic `funkin` save: the stars and the chosen order are menu
 * preferences, they are tiny, and a truncated flush of the big save must not
 * cost the player their favourites. `controls_v2` already proves the pattern
 * (see `ClientPrefs.loadPrefs`).
 *
 * Every read is defensive: a missing file, a blocked web storage or a
 * hand-edited save yields the defaults instead of an exception, and a sort mode
 * outside `FreeplaySort` is clamped rather than trusted.
 */
class FreeplayFilterStore
{
  /** FlxSave slot name; changing it discards every player's stars. */
  public static inline var SAVE_NAME:String = 'freeplay_filter';

  public static function load():FreeplayFilterState
  {
    final state:FreeplayFilterState = new FreeplayFilterState();
    try
    {
      final save:FlxSave = new FlxSave();
      if (!save.bind(SAVE_NAME, CoolUtil.getSavePath())) return state;

      final data:Dynamic = save.data;
      final sort:Dynamic = Reflect.field(data, 'sort');
      if (sort != null) state.setSort(Std.int(sort));

      final mod:Dynamic = Reflect.field(data, 'mod');
      if (Std.isOfType(mod, String)) state.setMod(cast mod);

      if (Reflect.field(data, 'favouritesOnly') == true) state.setFavouritesOnly(true);

      final stars:Dynamic = Reflect.field(data, 'stars');
      if (Std.isOfType(stars, Array))
      {
        final keys:Array<Dynamic> = cast stars;
        final clean:Array<String> = [];
        for (starKey in keys)
        {
          if (Std.isOfType(starKey, String) && clean.length < 4000) clean.push(cast starKey);
        }
        state.replaceStars(clean);
      }

      save.close();
    }
    catch (e:Dynamic)
    {
      // A broken save is not worth a crash: the player gets the plain list.
    }
    return state;
  }

  public static function save(state:FreeplayFilterState):Void
  {
    if (state == null) return;
    try
    {
      final save:FlxSave = new FlxSave();
      if (!save.bind(SAVE_NAME, CoolUtil.getSavePath())) return;

      save.data.sort = state.sort;
      save.data.mod = state.mod;
      save.data.favouritesOnly = state.favouritesOnly;
      save.data.stars = state.starKeys();
      save.flush();
      save.close();
    }
    catch (e:Dynamic)
    {
      // Losing a star is survivable; never let it take the menu down.
    }
  }
}
