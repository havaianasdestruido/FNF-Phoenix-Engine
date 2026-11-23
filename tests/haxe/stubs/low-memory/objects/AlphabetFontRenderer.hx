package objects;

/** Minimal `AlphabetFontRenderer` test double tracking glyph-page cache clears. */
class AlphabetFontRenderer
{
  public static var clears:Int = 0;

  /** Records a dynamic font glyph atlas clear. */
  public static function clearCache():Void
  {
    clears++;
  }
}
