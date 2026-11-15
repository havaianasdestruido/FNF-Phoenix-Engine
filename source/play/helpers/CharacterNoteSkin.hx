package play.helpers;

import backend.Paths;
import openfl.utils.AssetType;

/** Resolves character-specific skins without making assumptions about stage art. */
class CharacterNoteSkin
{
  /**
   * An empty result means use the chart's original skin. Pixel notes need
   * both the head/receptor sheet and the sustain sheet; a normal Sparrow
   * skin cannot be loaded from pixelUI. Paths memoizes these existence checks.
   */
  public static function resolve(name:String, pixel:Bool):String
  {
    if (name == null || name.length == 0) return '';
    final base:String = 'images/' + (pixel ? 'pixelUI/' : '') + 'noteskins/' + name;
    if (!Paths.fileExists(base + '.png', AssetType.IMAGE)) return '';
    if (!Paths.fileExists(base + (pixel ? 'ENDS.png' : '.xml'), pixel ? AssetType.IMAGE : AssetType.TEXT)) return '';
    return name;
  }
}
