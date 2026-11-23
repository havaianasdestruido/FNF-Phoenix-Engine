package objects;

/** Shape-matched stand-in for the note: the fields note types inject. */
class Note
{
  public function new() {}

  public var noteType:String = '';
  public var offsetX:Float = 0;
  public var offsetY:Float = 0;
  public var alpha:Float = 1;
  public var canMiss:Bool = false;
  public var extraData:Map<String, Dynamic> = new Map();
}
