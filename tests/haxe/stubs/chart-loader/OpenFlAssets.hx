class OpenFlAssets
{
  public static var existing:Map<String, Bool> = [];
  public static function exists(path:String):Bool return existing.exists(path);
}
