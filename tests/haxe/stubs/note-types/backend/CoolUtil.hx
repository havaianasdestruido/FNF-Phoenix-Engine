package backend;

/** Minimal stand-in: the real listFromString, verbatim. */
class CoolUtil
{
  public static function listFromString(string:String):Array<String>
  {
    final daList:Array<String> = string.trim().split('\n');
    return [for (i in 0...daList.length) daList[i].trim()];
  }
}
