package states;

/** Recording stand-in for the blank scripted host state. */
class ModState
{
  public static var created:Array<{name:String, data:Dynamic}> = [];

  public var name:String;
  public var data:Dynamic;

  public function new(name:String, ?data:Dynamic)
  {
    this.name = name;
    this.data = data;
    created.push({name: name, data: data});
  }

  public static function reset():Void
  {
    created = [];
  }
}
