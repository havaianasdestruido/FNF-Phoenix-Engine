class Assets
{
  public static var texts:Map<String, String> = [];
  public static function getText(path:String):String return texts.get(path);
  public static function exists(path:String):Bool return texts.exists(path);
}
