package backend.deeplink;

/** Version 1 menu-only URI contract. No decoding, filesystem access or execution. */
class PhoenixURI
{
  public static function parse(uri:String):Null<String>
  {
    if (uri == null || uri.length > 256) return null;
    // Restrict the whole input, rather than accepting a valid prefix.
    var syntax = ~/^phoenix:\/\/([a-z]+)(\/([a-z]+))?\/?$/i;
    if (!syntax.match(uri) || syntax.matched(0) != uri) return null;
    var host = syntax.matched(1).toLowerCase();
    var path = syntax.matched(3);
    if (host == "menu")
      host = path == null ? "main" : path.toLowerCase();
    else if (path != null)
      return null;
    return switch (host)
    {
      case "main", "mods", "options", "misc", "story", "freeplay", "credits": host;
      default: null;
    };
  }
}
