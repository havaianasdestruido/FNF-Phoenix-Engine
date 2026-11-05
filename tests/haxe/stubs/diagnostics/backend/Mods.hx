package backend;

class Mods
{
  public static var enabled:Array<String> = [];
  public static var disabled:Array<String> = [];
  public static var invalidMods:Array<String> = [];
  public static var currentModDirectory:String = '';

  public static function parseList():ModsList
    return {enabled: enabled.copy(), disabled: disabled.copy(), all: enabled.concat(disabled)};
}
